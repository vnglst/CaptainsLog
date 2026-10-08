#!/usr/bin/env ruby
# Implementation of run-evals.sh; standard-library only, no network services.
require 'json'
require 'yaml'
require 'digest'
require 'fileutils'
require 'optparse'
require 'open3'
require 'time'
require 'uri'
require_relative '../skills/enrich-eval/scripts/validate'

module Evals
  ROOT = File.expand_path('..', __dir__)
  STAGES = %w[transcribe cleanup filename enrich categorize].freeze
  DATE = '2025-01-15'
  TIME = '12:00'

  def self.json(path, data)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.pretty_generate(data) + "\n")
  end

  def self.hashes(paths)
    paths.sort.to_h { |path| [path, Digest::SHA256.file(path).hexdigest] }
  end

  def self.cases(stages, selected = nil)
    stages.flat_map do |stage|
      enrichment = nil
      if stage == 'enrich'
        EnrichEvaluation.validate_cases!("#{ROOT}/eval/enrich/cases.json", "#{ROOT}/eval/enrich/input")
        enrichment = JSON.parse(File.read("#{ROOT}/eval/enrich/cases.json"))
      end
      folder, extension = stage == 'transcribe' ? ['audio', 'm4a'] : ['input', 'md']
      inputs = Dir["#{ROOT}/eval/#{stage}/#{folder}/*.#{extension}"].sort
      inputs.select! { |path| File.basename(path, ".#{extension}") == selected } if selected
      raise "No fixtures for #{stage}#{selected ? "/#{selected}" : ''}" if inputs.empty?
      inputs.map do |input|
        name = File.basename(input, ".#{extension}")
        expected = "#{ROOT}/eval/#{stage}/expected/#{name}.#{stage == 'categorize' ? 'category' : 'md'}"
        raise "Missing expected fixture: #{expected}" unless File.file?(expected)
        item = { 'stage' => stage, 'name' => name, 'input' => input, 'expected' => expected }
        if enrichment
          item.merge!(enrichment.fetch(name).reject { |key, _| key == 'sha256' })
          item['input_sha256'] = enrichment.fetch(name)['sha256'] if enrichment.fetch(name)['sha256']
        end
        item
      end
    end
  end

  # Structural checks deliberately do not score semantic quality.
  def self.validate(item)
    text = File.read(item.fetch('output'), encoding: 'UTF-8')
    raise 'invalid UTF-8' unless text.valid_encoding?
    raise 'empty output' if text.strip.empty?
    raise 'NUL/control bytes in output' if text.match?(/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/)
    case item.fetch('stage')
    when 'filename'
      name = text.strip
      name += '.md' if item['scope'] == 'pipeline'
      raise 'filename must use supplied date and 3–8 lowercase kebab words' unless
        name.match?(/\A#{item.fetch('date', DATE)}-[\p{Ll}\p{N}]+(?:-[\p{Ll}\p{N}]+){2,7}\.md\z/)
    when 'categorize'
      data = JSON.parse(text)
      raise 'category manifest must contain only category and sourceStem' unless data.is_a?(Hash) && data.keys.sort == %w[category sourceStem]
      raise 'sourceStem mismatch' unless data['sourceStem'] == item.fetch('name')
      raise 'category mismatch' unless data['category'] == File.read(item.fetch('expected')).strip
    when 'enrich'
      match = /\A---\n(.*?)\n---\n\n(.*)\z/m.match(text)
      raise 'missing or malformed frontmatter delimiters' unless match
      # safe_load rejects aliases and non-basic types; AST check rejects duplicate keys.
      tree = YAML.parse(match[1])
      mapping = tree && tree.root
      raise 'frontmatter must be a mapping' unless mapping.is_a?(Psych::Nodes::Mapping)
      keys = mapping.children.each_slice(2).map do |key, _|
        raise 'frontmatter keys must be scalar strings' unless key.is_a?(Psych::Nodes::Scalar)
        key.value
      end
      raise 'duplicate frontmatter keys' unless keys.uniq == keys
      raise 'multiple YAML documents' unless Psych.parse_stream(match[1]).children.length == 1
      data = YAML.safe_load(match[1], permitted_classes: [], aliases: false)
      required = %w[date recording_time language categories tags persons projects companies entities summary]
      raise 'incorrect frontmatter fields' unless data.is_a?(Hash) && data.keys.sort == required.sort
      %w[categories tags persons projects companies entities].each do |key|
        value = data[key]
        raise "#{key} must be a list of nonempty strings" unless value.is_a?(Array) &&
          value.all? { |entry| entry.is_a?(String) && !entry.strip.empty? }
      end
      %w[date recording_time language summary].each do |key|
        raise "#{key} must be nonempty text" unless data[key].is_a?(String) && !data[key].strip.empty?
      end
      raise 'date differs from supplied date' unless data['date'] == item.fetch('date', DATE)
      supplied_time = item['recording_time']
      raise 'recording_time differs from supplied time' if supplied_time && data['recording_time'] != supplied_time
      raise 'invalid recording_time' unless data['recording_time'].match?(/\A(?:[01]\d|2[0-3]):[0-5]\d\z/)
      raise 'categories must use personal, work or side-project' if data['categories'].empty? || (data['categories'] - %w[personal work side-project]).any?
      source = File.read(item.fetch('input'), encoding: 'UTF-8')
      raise 'source body changed' unless match[2] == source
      EnrichEvaluation.validate_case_input!(item['input'], { 'sha256' => item['input_sha256'] }) if item['input_sha256']
      expected = YAML.safe_load(File.read(item.fetch('expected')).split('---', 3)[1])
      expected.merge!('date' => item.fetch('date', DATE), 'recording_time' => item.fetch('recording_time', TIME))
      EnrichEvaluation.validate!(source, text, expected)
    when 'cleanup', 'transcribe'
      raise 'model wrapper or special token leaked into text' if text.match?(/<\|(?:im_start|im_end|endoftext)\|>|<\/?think>|\A```/)
    else
      raise 'unknown stage'
    end
    'PASS'
  rescue StandardError => error
    "FAIL: #{error.message}"
  end

  def self.link(path)
    URI::DEFAULT_PARSER.escape(path, /[^a-zA-Z0-9\-._~\/]/)
  end

  def self.evidence(run, items, baseline = nil)
    failures = 0
    index = ["# Evaluation review", '', 'Mechanical success does not establish semantic quality. Read every selected case; owner judgment remains required.', '']
    items.each do |item|
      relative = "review/#{item.fetch('scope', 'suites')}/#{item.fetch('stage')}/#{item.fetch('name')}"
      folder = "#{run}/#{relative}"
      FileUtils.mkdir_p(folder)
      %w[input expected output].each do |key|
        path = item.fetch(key)
        FileUtils.cp(path, "#{folder}/#{key}#{File.extname(path)}") if File.file?(path)
      end
      status = validate(item)
      failures += 1 unless status == 'PASS'
      puts "#{item['stage']}/#{item['name']}: #{status}"
      File.write("#{folder}/validation.txt", status + "\n")
      parts = ["# #{item['stage']}/#{item['name']}", '', "Validation: #{status}", '',
               "Input: [#{item['input']}](#{link(item['input'])})", '',
               '## Input', '', item['stage'] == 'transcribe' ? '(Audio fixture linked above.)' : (File.file?(item['input']) ? File.read(item['input']) : '(missing)'), '',
               '## Expected', '', File.file?(item['expected']) ? File.read(item['expected']) : '(missing)', '', '## Generated', '',
               File.file?(item['output']) ? File.read(item['output']).scrub : '(missing)', '']
      # Unified diffs are an optional change-navigation aid, never cleanup scoring.
      if baseline
        previous = baseline.find { |entry| entry['scope'] == item['scope'] && entry['stage'] == item['stage'] && entry['name'] == item['name'] }
        if previous && File.file?(previous['output']) && File.file?(item['output'])
          FileUtils.cp(previous['output'], "#{folder}/baseline#{File.extname(previous['output'])}")
          diff, result = Open3.capture2('diff', '-u', previous['output'], item['output'])
          raise 'baseline diff failed' unless [0, 1].include?(result.exitstatus)
          File.write("#{folder}/baseline.diff", diff)
          parts += ['## Baseline changes (navigation only)', '', '```diff', diff, '```', '']
        else
          parts += ['Baseline: no matching saved output.', '']
        end
      end
      report = ['# Semantic review (fill after reading)', '',
                '- Omissions / changed meaning: pending', '- Added or hallucinated content: pending',
                '- Improvements / regressions against baseline: pending (or no baseline)',
                '- Stage-specific observations: pending', '- Judgment and remaining limits: pending owner review', '']
      File.write("#{folder}/report.md", report.join("\n")) unless File.exist?("#{folder}/report.md")
      parts += ['[Semantic report](report.md)', '']
      File.write("#{folder}/review.md", parts.join("\n"))
      index << "- [#{item['stage']}/#{item['name']}](#{link("#{relative}/review.md")}): #{status}"
    end
    File.write("#{run}/review.md", index.join("\n") + "\n")
    json("#{run}/validation.json", { 'cases' => items.length, 'failures' => failures, 'validator_sha256' => Digest::SHA256.file(__FILE__).hexdigest, 'enrichment_validator_sha256' => Digest::SHA256.file("#{ROOT}/skills/enrich-eval/scripts/validate.rb").hexdigest })
    puts "Validated #{items.length} cases; failures: #{failures}. Review: #{run}/review.md"
    failures.zero?
  end

  def self.command(*args, log:)
    FileUtils.mkdir_p(File.dirname(log))
    File.open(log, 'w') do |file|
      Open3.popen2e(*args) do |stdin, stdout, wait|
        stdin.close
        stdout.each_line { |line| file.write(line); puts line }
        raise "Command failed (#{wait.value.exitstatus}); see #{log}" unless wait.value.success?
      end
    end
  end

  def self.settings
    # Read defaults from the compiled source inputs, rather than trusting a model label.
    llm = File.read("#{ROOT}/Sources/CaptainsLogCore/LLM.swift")
    STAGES.reject { |s| s == 'transcribe' }.to_h do |stage|
      source = File.read("#{ROOT}/Sources/CaptainsLogCore/#{stage.capitalize}.swift")
      max_tokens = source[/defaultMaxTokens = ([\d_]+)/, 1] || llm[/maxTokens: Int = (\d+)/, 1]
      temperature = source[/defaultTemperature: Float = ([\d.]+)/, 1] || llm[/temperature: Float = ([\d.]+)/, 1]
      raise 'Cannot resolve generation defaults' unless max_tokens && temperature
      [stage, { 'max_tokens' => max_tokens.delete('_').to_i, 'temperature' => temperature.to_f,
                'prevent_repetition' => stage == 'enrich',
                'top_k' => Integer(llm[/llama_sampler_init_top_k\((\d+)\)/, 1]),
                'top_p' => Float(llm[/llama_sampler_init_top_p\(([\d.]+),/, 1]),
                'dry' => stage == 'enrich' ? llm[/llama_sampler_init_dry\(vocab, ([^)]+)\)/, 1] : nil,
                'seed_policy' => stage == 'enrich' ? 'per-case manifest seed; pipeline uses random default' : 'LLAMA_DEFAULT_SEED (random per fresh sampler)',
                'context_policy' => 'LLM.plannedContextSize; fresh context per call',
                'parameter_scope' => 'stage defaults; date/time are per-case manifest values' }]
    end.merge('transcribe' => { 'language' => 'auto-detect', 'skip_special_tokens' => true,
                                'audio_encoder_compute' => 'cpuAndGPU', 'text_decoder_compute' => 'cpuAndGPU' })
  end

  def self.main(argv)
    options = { mode: '--all' }
    parser = OptionParser.new do |o|
      o.banner = 'Usage: scripts/run-evals.sh [--all|--pipeline|--suites|--categorize|--enrich|--stage STAGE [--case STEM]] [--baseline RUN_DIR]'
      %w[all pipeline suites categorize enrich].each { |mode| o.on("--#{mode}") { raise 'Choose one execution mode' if options[:explicit]; options[:mode] = "--#{mode}"; options[:explicit] = true } }
      o.on('--stage STAGE', STAGES) { |value| raise 'Choose one execution mode' if options[:explicit]; options[:mode] = '--stage'; options[:stage] = value; options[:explicit] = true }
      o.on('--case STEM') { |value| options[:case] = value }
      o.on('--baseline RUN_DIR') { |value| options[:baseline] = File.expand_path(value) }
      o.on('--validate-run RUN_DIR_OR_STAMP') { |value| options[:validate] = value }
      o.on('--validate-enrich STAMP') { |value| options[:validate] = value; options[:legacy_enrich] = true }
      o.on('--validate-categorize STAMP') { |value| options[:validate] = value; options[:legacy_category] = true }
      o.on('--list') { options[:list] = true }
      o.on('-h', '--help') { puts o; return 0 }
    end
    parser.parse!(argv)
    raise "Unexpected arguments: #{argv.join(' ')}" unless argv.empty?
    raise '--case requires --stage' if options[:case] && !options[:stage]
    stages = options[:stage] ? [options[:stage]] : %w[--categorize --enrich].include?(options[:mode]) ? [options[:mode].delete_prefix('--')] : STAGES
    if options[:validate]
      raise 'Validation cannot be combined with execution options' if options[:explicit] || options[:case] || options[:list]
      value = options[:validate]
      if File.file?("#{value}/manifest.json")
        run = File.expand_path(value)
        items = JSON.parse(File.read("#{run}/manifest.json"))
      else
        raise 'Expected saved run directory or timestamp' unless value.match?(/\A[\w.-]+\z/)
        run = "#{ROOT}/tmp/eval-validation-#{value}"
        items = cases(options[:legacy_category] ? ['categorize'] : options[:legacy_enrich] ? ['enrich'] : STAGES)
        name_outputs(items, value)
      end
      raise 'Saved manifest has no cases' unless items.is_a?(Array) && !items.empty?
      refresh_pipeline_outputs(run, items)
      enrich_pipeline_parameters(run, items)
      json("#{run}/manifest.json", items) if File.file?("#{run}/manifest.json")
      recorded_baseline = File.file?("#{run}/metadata.json") ? JSON.parse(File.read("#{run}/metadata.json"))['baseline'] : nil
      return evidence(run, items, baseline_items(options[:baseline] || recorded_baseline)) ? 0 : 1
    end
    items = options[:mode] == '--pipeline' ? [] : cases(stages, options[:case])
    if options[:list]
      items.each { |item| puts "#{item['stage']}/#{item['name']}" }
      return 0
    end
    baseline = baseline_items(options[:baseline])
    stamp = "#{Time.now.strftime('%Y-%m-%d_%H-%M-%S')}_#{Process.pid}"
    run = File.expand_path(ENV.fetch('CAPTAINS_LOG_EVAL_RUN_DIR', "#{ROOT}/tmp/evals-#{stamp}"))
    raise "Run directory already exists: #{run}" if File.exist?(run)
    name_outputs(items, stamp)
    FileUtils.mkdir_p(run)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    metadata = { 'stamp' => stamp, 'started_at' => Time.now.utc.iso8601, 'mode' => options[:mode],
                 'revision' => capture('git', 'rev-parse', 'HEAD').strip,
                 'dirty_status' => capture('git', 'status', '--porcelain'), 'generation' => settings,
                 'baseline' => options[:baseline], 'status' => 'preparing' }
    begin
      if items.any? { |item| item['stage'] == 'enrich' }
        FileUtils.cp("#{ROOT}/eval/enrich/cases.json", "#{run}/enrich-cases.json")
        metadata['enrich_cases_sha256'] = Digest::SHA256.file("#{run}/enrich-cases.json").hexdigest
        items.select { |item| item['stage'] == 'enrich' }.each { |item| item['diagnostics'] = "#{run}/enrich-#{item['name']}.log" }
      end
      configure(run, stages, options[:mode], metadata)
      # Snapshot fixtures so saved-run review remains meaningful after fixture edits.
      items.each do |item|
        folder = "#{run}/fixtures/#{item['stage']}/#{item['name']}"
        FileUtils.mkdir_p(folder)
        %w[input expected].each do |key|
          destination = "#{folder}/#{key == 'input' ? item['name'] : 'expected'}#{File.extname(item[key])}"
          FileUtils.cp(item[key], destination)
          item[key] = destination
        end
      end
      if %w[--all --pipeline].include?(options[:mode])
        pipeline_items = pipeline_cases(run)
        pipeline_items.each do |item|
          folder = "#{run}/fixtures/pipeline/#{item['stage']}"
          FileUtils.mkdir_p(folder)
          path = "#{folder}/expected#{File.extname(item['expected'])}"
          FileUtils.cp(item['expected'], path)
          item['expected'] = path
          if item['stage'] == 'transcribe'
            path = "#{folder}/#{File.basename(item['input'])}"
            FileUtils.cp(item['input'], path)
            item['input'] = path
          end
        end
        items.concat(pipeline_items)
      end
      json("#{run}/manifest.json", items)
      metadata['fixture_hashes'] = hashes(items.flat_map { |item| item.values_at('input', 'expected') }.select { |p| File.file?(p) })
      metadata['source_hashes'] = hashes(Dir["#{ROOT}/Sources/{CaptainsLogCore,cl}/*.swift"] + Dir["#{ROOT}/scripts/*eval*"] + ["#{ROOT}/Package.resolved", "#{ROOT}/skills/enrich-eval/scripts/validate.rb"])
      metadata['prompt_hashes'] = hashes(Dir["#{ROOT}/prompts/*.md"])
      metadata['status'] = 'running'
      json("#{run}/metadata.json", metadata)
      puts "Run: #{run} (#{items.length} cases)"
      command('swift', 'build', '--product', 'cl', log: "#{run}/build.log")
      cl = File.join(capture('swift', 'build', '--show-bin-path').strip, 'cl')
      metadata['binary_sha256'] = Digest::SHA256.file(cl).hexdigest
      metadata['swift_version'] = capture('swift', '--version').strip
      metadata['runtime'] = capture('otool', '-L', cl)
      libs = metadata['runtime'].lines.drop(1).map { |line| line.strip.split(' (').first }.select { |p| p.include?('/opt/homebrew/') && File.file?(p) }
      metadata['runtime_hashes'] = hashes(libs)
      json("#{run}/metadata.json", metadata)
      if items.any? { |item| item['stage'] == 'enrich' }
        command('env', "CAPTAINS_LOG_EVAL_CL=#{cl}", 'bash', "#{ROOT}/scripts/test-enrich-eval.sh", log: "#{run}/enrich-checks.log")
      end
      if %w[--all --pipeline].include?(options[:mode])
        command('bash', "#{ROOT}/scripts/eval-pipeline.sh", run, cl, log: "#{run}/pipeline-checks.log")
      end
      items.select { |item| item['stage'] == 'transcribe' && item['scope'] != 'pipeline' }.each do |item|
        command(cl, 'transcribe', item['input'], '--output', item['output'], log: "#{run}/transcribe-#{item['name']}.log")
      end
      text_items = items.reject { |item| item['stage'] == 'transcribe' || item['scope'] == 'pipeline' }
      unless text_items.empty?
        json("#{run}/batch.json", text_items)
        command(cl, 'eval-batch', '--manifest', "#{run}/batch.json", log: "#{run}/batch.log")
      end
      metadata['status'] = 'generated'
    rescue StandardError => error
      metadata['status'] = 'failed'
      metadata['error'] = error.message
      warn error.message
    ensure
      refresh_pipeline_outputs(run, items)
      record_pipeline_metadata(run, items, metadata)
      json("#{run}/manifest.json", items)
      valid = evidence(run, items, baseline)
      metadata['status'] = valid ? 'passed-mechanical-checks' : 'failed-validation' if metadata['status'] == 'generated'
      metadata['elapsed_seconds'] = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      json("#{run}/metadata.json", metadata)
    end
    metadata['status'] == 'passed-mechanical-checks' ? 0 : 1
  end

  def self.pipeline_cases(run)
    stem = '2025-01-14 side project'
    data = "#{run}/data/.pipeline"
    transcript = "#{data}/01-transcribed/#{stem}.md"
    cleaned = "#{data}/02-logs/#{stem}.md"
    [
      ['transcribe', "#{ROOT}/eval/transcribe/audio/#{stem}.m4a", transcript, "#{ROOT}/eval/transcribe/expected/#{stem}.md"],
      ['cleanup', transcript, cleaned, "#{ROOT}/eval/cleanup/expected/#{stem}.md"],
      ['categorize', cleaned, "#{data}/03-category/#{stem}.json", "#{ROOT}/eval/categorize/expected/side-project-voice-app.category"],
      ['filename', cleaned, "#{data}/04-rename/#{stem}.slug.txt", "#{ROOT}/eval/filename/expected/#{stem}.md"],
      ['enrich', cleaned, "#{run}/data/logs/missing.md", "#{ROOT}/eval/enrich/expected/#{stem}.md"]
    ].map do |stage, input, output, expected|
      { 'scope' => 'pipeline', 'stage' => stage, 'name' => stem, 'input' => input,
        'output' => output, 'expected' => expected, 'date' => '2025-01-14' }
    end
  end

  def self.refresh_pipeline_outputs(run, items)
    enriched = items.find { |item| item['scope'] == 'pipeline' && item['stage'] == 'enrich' }
    return unless enriched
    slug_file = "#{run}/data/.pipeline/04-rename/2025-01-14 side project.slug.txt"
    return unless File.file?(slug_file)
    slug = File.read(slug_file).strip
    path = Dir["#{run}/data/logs/*/*.md"].find { |p| File.basename(p) == "#{slug}.md" }
    enriched['output'] = path if path
  end

  def self.enrich_pipeline_parameters(run, items)
    audio = "#{run}/data/audio/2025-01-14 side project.m4a"
    return unless File.file?(audio)
    time = File.birthtime(audio).strftime('%H:%M')
    items.select { |item| item['scope'] == 'pipeline' }.each { |item| item['recording_time'] = time }
  end

  def self.record_pipeline_metadata(run, items, metadata)
    enrich_pipeline_parameters(run, items)
    pipeline = items.select { |item| item['scope'] == 'pipeline' }
    return if pipeline.empty?
    metadata['pipeline_parameters'] = pipeline.map { |item| item.slice('stage', 'date', 'recording_time') }
    # Search is a pipeline readback check, separate from the stage generators.
    if File.file?("#{run}/data/.search/search.sqlite")
      path = File.join(Dir.home, 'Library/Application Support/CaptainsLog/models/embeddings/multilingual-e5-small-q8_0.gguf')
      metadata['models']['embeddings'] = { 'path' => path, 'bytes' => File.size(path), 'sha256' => Digest::SHA256.file(path).hexdigest }
    end
  end

  def self.capture(*args)
    output, status = Open3.capture2(*args)
    raise "Failed: #{args.join(' ')}" unless status.success?
    output
  end

  def self.baseline_items(path)
    path && JSON.parse(File.read("#{path}/manifest.json"))
  end

  def self.name_outputs(items, stamp)
    items.each do |item|
      label = item['stage'] == 'transcribe' ? ENV.fetch('CAPTAINS_LOG_EVAL_WHISPER_MODEL', 'openai_whisper-large-v2') : ENV.fetch('CAPTAINS_LOG_EVAL_QWEN_LABEL', 'Qwen3.5-9B-Q4_K_M')
      raise 'Model label must be a filename component' unless label.match?(/\A[\w.-]+\z/)
      extension = item['stage'] == 'categorize' ? 'json' : 'md'
      item['output'] = "#{ROOT}/eval/#{item['stage']}/generated/#{stamp}_#{label}_#{item['name']}.#{extension}"
      item['date'] ||= DATE
      item['recording_time'] ||= TIME
    end
  end

  def self.configure(run, stages, mode, metadata)
    pipeline = %w[--all --pipeline].include?(mode)
    config = { 'schemaVersion' => 1, 'dataDir' => "#{run}/data" }
    models = {}
    if pipeline || (stages - ['transcribe']).any?
      folder = ENV.fetch('CAPTAINS_LOG_EVAL_QWEN_FOLDER', "#{Dir.home}/Library/Application Support/CaptainsLog/models")
      path = File.realpath(File.join(folder, ENV.fetch('CAPTAINS_LOG_EVAL_QWEN_FILE', 'Qwen_Qwen3.5-9B-Q4_K_M.gguf')))
      raise "Not a Qwen file: #{path}" unless File.file?(path)
      # Pin the exact selected file even if its original folder contains other GGUFs.
      FileUtils.mkdir_p("#{run}/models")
      File.symlink(path, "#{run}/models/Qwen_Qwen3.5-9B-Q4_K_M.gguf")
      config['qwenModelFolder'] = "#{run}/models"
      models['qwen'] = { 'path' => path, 'bytes' => File.size(path), 'sha256' => Digest::SHA256.file(path).hexdigest }
    end
    if pipeline || stages.include?('transcribe')
      model = ENV.fetch('CAPTAINS_LOG_EVAL_WHISPER_MODEL', 'openai_whisper-large-v2')
      folder = File.realpath(ENV.fetch('CAPTAINS_LOG_EVAL_WHISPER_FOLDER', "#{Dir.home}/Library/Caches/CaptainsLog/models/whisper/models/argmaxinc/whisperkit-coreml/#{model}"))
      config.merge!('whisperModel' => model, 'whisperModelFolder' => folder)
      models['whisper'] = { 'path' => folder, 'model' => model, 'file_hashes' => hashes(Dir["#{folder}/**/*"].select { |p| File.file?(p) }) }
    end
    metadata['models'] = models
    json("#{run}/config.json", config)
    ENV['CAPTAINS_LOG_CONFIG_PATH'] = "#{run}/config.json"
    ENV['CAPTAINS_LOG_DATA_DIR'] = "#{run}/data"
  end
end

if $PROGRAM_NAME == __FILE__
  Dir.chdir(Evals::ROOT)
  begin
    exit Evals.main(ARGV)
  rescue StandardError => error
    warn "Evaluation error: #{error.message}"
    exit 2
  end
end

#!/usr/bin/env ruby
# Deterministic checks for selection, rejection and evidence; no inference.
require_relative 'evals'
require 'tmpdir'

checks = 0
assert = lambda do |condition, message|
  raise message unless condition
  checks += 1
end
Dir.mktmpdir('captainslog-eval-tests-') do |run|
  input = Evals.cases(['enrich'], '01_work_week').first
  input['output'] = "#{run}/generated.md"
  input['recording_time'] = '12:00'
  body = File.read(input['input'])
  data = {
    'date' => '2025-01-15', 'recording_time' => '12:00', 'language' => 'en',
    'categories' => ['work'], 'tags' => [], 'persons' => [], 'projects' => [],
    'companies' => [], 'entities' => [], 'summary' => 'A work week.'
  }
  write = lambda { |value, text = body| File.write(input['output'], "#{YAML.dump(value)}---\n\n#{text}") }
  write.call(data)
  assert.call(Evals.validate(input) == 'PASS', 'valid enrichment rejected')
  [nil, {}, data.merge('tags' => [nil]), data.merge('entities' => [{ 'Apple' => 'company' }]),
   data.merge('persons' => ['']), data.merge('summary' => ''), data.merge('language' => ''),
   data.merge('date' => '2025-01-14'), data.merge('recording_time' => '25:00'),
   data.merge('categories' => []), data.merge('categories' => ['finance']), data.merge('extra' => 'field')].each do |value|
    write.call(value)
    assert.call(Evals.validate(input).start_with?('FAIL:'), "malformed enrichment accepted: #{value.inspect}")
  end
  write.call(data, body + 'Added fact.')
  assert.call(Evals.validate(input).include?('source body changed'), 'body mutation accepted')
  write.call(data)
  File.write(input['output'], File.read(input['output']).sub('language: en', "language: en\nlanguage: nl"))
  assert.call(Evals.validate(input).include?('duplicate'), 'duplicate YAML key accepted')
  File.write(input['output'], "---\ntags: [broken\n---\n\n#{body}")
  assert.call(Evals.validate(input).start_with?('FAIL:'), 'broken YAML accepted')
  File.write(input['output'], "---\nentities: &entity [Apple]\ntags: *entity\n---\n\n#{body}")
  assert.call(Evals.validate(input).start_with?('FAIL:'), 'YAML alias accepted')
  File.write(input['output'], "\xFF".b)
  assert.call(Evals.validate(input).include?('UTF-8'), 'invalid UTF-8 accepted')
  File.delete(input['output'])
  assert.call(Evals.validate(input).start_with?('FAIL:'), 'missing output accepted')

  filename = Evals.cases(['filename'], '04_short_entry').first.merge('output' => "#{run}/filename.md")
  File.write(filename['output'], "2025-01-15-three-grounded-words.md\n")
  assert.call(Evals.validate(filename) == 'PASS', 'valid filename rejected')
  %W[2025-01-15-two-words.md 2025-01-15-Upper-case-word.md 2025-01-14-three-grounded-words.md].each do |name|
    File.write(filename['output'], name)
    assert.call(Evals.validate(filename).start_with?('FAIL:'), 'invalid filename accepted')
  end
  File.write(filename['output'], "2025-01-15-three-grounded-words.md\nExplanation")
  assert.call(Evals.validate(filename).start_with?('FAIL:'), 'multiline filename accepted')

  category = Evals.cases(['categorize'], 'personal-weekend').first.merge('output' => "#{run}/category.json")
  [%w[personal-weekend personal], %w[wrong personal], %w[personal-weekend professional]].each_with_index do |(stem, label), index|
    File.write(category['output'], JSON.generate('sourceStem' => stem, 'category' => label))
    assert.call((Evals.validate(category) == 'PASS') == index.zero?, 'category validation mismatch')
  end
  cleanup = Evals.cases(['cleanup'], 'book-reference').first.merge('output' => "#{run}/cleanup.md")
  ['', '<think>private reasoning</think>', "bad\x00text", '```output'].each do |text|
    File.write(cleanup['output'], text)
    assert.call(Evals.validate(cleanup).start_with?('FAIL:'), 'malformed cleanup accepted')
  end
  File.write(cleanup['output'], File.read(cleanup['expected']))
  assert.call(Evals.validate(cleanup) == 'PASS', 'valid cleanup rejected')
  assert.call(Evals.cases(Evals::STAGES).length == 23, 'suite selection changed unexpectedly')
  assert.call(Evals.cases(['filename'], '04_short_entry').length == 1, 'case selection mismatch')
  begin
    Evals.cases(['cleanup'], 'missing')
    raise 'unknown fixture silently skipped'
  rescue RuntimeError => error
    assert.call(error.message.include?('No fixtures'), 'wrong unknown-fixture error')
  end
  write.call(data)
  assert.call(Evals.evidence(run, [input]), 'valid evidence failed')
  assert.call(File.file?("#{run}/review/suites/enrich/01_work_week/input.md"), 'missing input snapshot')
  report_path = "#{run}/review/suites/enrich/01_work_week/report.md"
  original_review = File.read(report_path)
  File.write(report_path, original_review + 'Authored finding')
  assert.call(original_review.include?('Added or hallucinated'), 'missing review guidance')
  baseline = input.merge('output' => "#{run}/baseline.md")
  File.write(baseline['output'], File.read(input['output']).sub('work week', 'week at work'))
  assert.call(Evals.evidence(run, [input], [baseline]), 'baseline evidence failed')
  assert.call(File.read(report_path).include?('Authored finding'), 'revalidation overwrote authored review')
  assert.call(File.read("#{run}/review/suites/enrich/01_work_week/baseline.diff").include?('week at work'), 'missing baseline diff')
  write.call(data, body + 'Changed')
  Evals.json("#{run}/manifest.json", [input])
  output, status = Open3.capture2e('bash', "#{Evals::ROOT}/scripts/run-evals.sh", '--validate-run', run)
  assert.call(status.exitstatus == 1 && output.include?('source body changed'), 'validator failure did not fail CLI')
  output, status = Open3.capture2e('bash', "#{Evals::ROOT}/scripts/run-evals.sh", '--stage', 'filename', '--case', '04_short_entry', '--list')
  assert.call(status.success? && output.strip == 'filename/04_short_entry', 'CLI selection mismatch')
  output, status = Open3.capture2e('bash', "#{Evals::ROOT}/scripts/run-evals.sh", '--suites', '--case', '04_short_entry')
  assert.call(status.exitstatus == 2 && output.include?('--case requires'), 'ambiguous selection accepted')
  assert.call(Evals.settings['enrich']['max_tokens'] == 4096, 'generation defaults not resolved')
  Evals.json("#{run}/manifest.json", [])
  _, status = Open3.capture2e('bash', "#{Evals::ROOT}/scripts/run-evals.sh", '--validate-run', run)
  assert.call(status.exitstatus == 2, 'empty saved manifest accepted')
  # Exercise the real orchestrator with subprocess fixtures. Fake executables
  # replace only native/build tools; configuration, selection, hashing, batching,
  # saved validation and evidence use the production implementation.
  bin = "#{run}/bin"
  FileUtils.mkdir_p(bin)
  File.write("#{bin}/swift", "#!/bin/sh\nif [ \"$1\" = \"--version\" ]; then echo fixture-swift; elif [ \"$2\" = \"--show-bin-path\" ]; then echo '#{bin}'; fi\n")
  File.write("#{bin}/otool", "#!/bin/sh\necho fixture-runtime\n")
  File.write("#{bin}/cl", <<~'FAKE')
    #!/usr/bin/env ruby
    require 'json'
    require 'fileutils'
    require 'yaml'
    root = ENV.fetch('EVAL_FIXTURE_ROOT')
    File.open(ENV.fetch('EVAL_FIXTURE_CALLS'), 'a') { |f| f.puts(ARGV.first) }
    if ARGV.first == 'eval-batch'
      JSON.parse(File.read(ARGV.fetch(2))).each do |item|
        expected = File.read(item.fetch('expected'))
        if item['stage'] == 'enrich'
          yaml = expected.split('---', 3)[1]
          data = YAML.safe_load(yaml)
          %w[categories tags persons projects companies entities].each { |key| data[key] ||= [] }
          data['date'] = '2025-01-15'
          data['recording_time'] = '12:00'
          expected = "#{YAML.dump(data)}---\n\n#{File.read(item.fetch('input'))}"
        elsif item['stage'] == 'categorize'
          expected = JSON.generate('sourceStem' => item['name'], 'category' => expected.strip)
        elsif item['stage'] == 'filename'
          expected = expected.sub(/\A\d{4}-\d{2}-\d{2}/, '2025-01-15')
        end
        FileUtils.mkdir_p(File.dirname(item.fetch('output')))
        File.write(item.fetch('output'), expected)
      end
    elsif ARGV.first == 'transcribe'
      name = File.basename(ARGV.fetch(1), '.m4a')
      path = ARGV.fetch(3)
      FileUtils.mkdir_p(File.dirname(path))
      FileUtils.cp("#{root}/eval/transcribe/expected/#{name}.md", path)
    elsif ARGV.first == 'pipeline'
      run = ENV.fetch('CAPTAINS_LOG_DATA_DIR')
      stem = '2025-01-14 side project'
      slug = '2025-01-14-side-project-star-trek-voice-log.md'
      transcript = File.read("#{root}/eval/transcribe/expected/#{stem}.md")
      cleaned = File.read("#{root}/eval/cleanup/expected/#{stem}.md")
      frontmatter = YAML.safe_load(File.read("#{root}/eval/enrich/expected/#{stem}.md").split('---', 3)[1])
      frontmatter['date'] = '2025-01-14'
      FileUtils.mkdir_p("#{run}/audio")
      FileUtils.cp("#{root}/eval/transcribe/audio/#{stem}.m4a", "#{run}/audio/#{stem}.m4a")
      frontmatter['recording_time'] = File.birthtime("#{run}/audio/#{stem}.m4a").strftime('%H:%M')
      artifacts = {
        ".pipeline/01-transcribed/#{stem}.md" => transcript,
        ".pipeline/02-logs/#{stem}.md" => cleaned,
        ".pipeline/03-category/#{stem}.json" => JSON.generate('sourceStem' => stem, 'category' => 'side_project'),
        ".pipeline/04-rename/#{stem}.slug.txt" => slug.delete_suffix('.md'),
        ".pipeline/04-rename/#{slug}" => cleaned,
        "logs/side-project/#{slug}" => "#{YAML.dump(frontmatter)}---\n\n#{cleaned}"
      }
      artifacts.each do |relative, text|
        next if ENV['EVAL_FIXTURE_OMIT_ENRICH'] && relative.start_with?('logs/')
        FileUtils.mkdir_p(File.dirname("#{run}/#{relative}"))
        File.write("#{run}/#{relative}", text)
      end
    elsif ARGV.first == 'search'
      puts "#{ENV.fetch('CAPTAINS_LOG_DATA_DIR')}/logs/side-project/2025-01-14-side-project-star-trek-voice-log.md"
    elsif %w[resume search-index].include?(ARGV.first)
      puts 'fixture no-op'
    else
      abort 'unexpected fixture command' 
    end
  FAKE
  Dir["#{bin}/*"].each { |path| File.chmod(0755, path) }
  model_folder = "#{run}/models"
  FileUtils.mkdir_p(model_folder)
  FileUtils.cp(input['input'], "#{model_folder}/fixture.gguf")
  whisper_folder = "#{run}/whisper"
  FileUtils.mkdir_p(whisper_folder)
  FileUtils.cp(input['input'], "#{whisper_folder}/fixture-model")
  env = { 'PATH' => "#{bin}:#{ENV['PATH']}", 'CAPTAINS_LOG_EVAL_QWEN_FOLDER' => model_folder,
          'CAPTAINS_LOG_EVAL_QWEN_FILE' => 'fixture.gguf', 'CAPTAINS_LOG_EVAL_WHISPER_FOLDER' => whisper_folder,
          'EVAL_FIXTURE_ROOT' => Evals::ROOT, 'EVAL_FIXTURE_CALLS' => "#{run}/calls" }
  # Generated outputs stay in ignored eval/generated; names are unique per run.
  begin
    saved = "#{run}/suite"
    output, status = Open3.capture2e(env.merge('CAPTAINS_LOG_EVAL_RUN_DIR' => saved), 'bash', "#{Evals::ROOT}/scripts/run-evals.sh", '--suites')
    assert.call(status.success?, "suite fixture failed: #{output}")
    manifest = JSON.parse(File.read("#{saved}/manifest.json"))
    assert.call(manifest.length == 23, 'full suite dropped cases')
    calls = File.readlines("#{run}/calls", chomp: true)
    assert.call(calls == %w[transcribe transcribe transcribe transcribe eval-batch], 'suite did not batch text after sequential audio')
    metadata = JSON.parse(File.read("#{saved}/metadata.json"))
    assert.call(metadata.dig('models', 'qwen', 'sha256') == Digest::SHA256.file(input['input']).hexdigest, 'actual model identity missing')
    assert.call(metadata['status'] == 'passed-mechanical-checks' && metadata['fixture_hashes'].size == 46, 'suite metadata incomplete')
    focused = "#{run}/focused"
    output, status = Open3.capture2e(env.merge('CAPTAINS_LOG_EVAL_RUN_DIR' => focused, 'CAPTAINS_LOG_EVAL_WHISPER_FOLDER' => '/missing-whisper'), 'bash', "#{Evals::ROOT}/scripts/run-evals.sh", '--stage', 'filename', '--case', '04_short_entry', '--baseline', saved)
    assert.call(status.success?, "focused fixture required unrelated model: #{output}")
    assert.call(JSON.parse(File.read("#{focused}/manifest.json")).size == 1, 'focused run included other cases')
    output, status = Open3.capture2e(env.merge('CAPTAINS_LOG_EVAL_RUN_DIR' => focused), 'bash', "#{Evals::ROOT}/scripts/run-evals.sh", '--stage', 'filename')
    assert.call(status.exitstatus == 2 && output.include?('already exists'), 'run overwrite accepted')
    failed = "#{run}/missing-model"
    output, status = Open3.capture2e(env.merge('CAPTAINS_LOG_EVAL_RUN_DIR' => failed, 'CAPTAINS_LOG_EVAL_QWEN_FOLDER' => '/missing-qwen'), 'bash', "#{Evals::ROOT}/scripts/run-evals.sh", '--stage', 'filename', '--case', '04_short_entry')
    assert.call(status.exitstatus == 1 && JSON.parse(File.read("#{failed}/metadata.json"))['status'] == 'failed', 'missing model failure was not retained')
    pipeline = "#{run}/pipeline"
    output, status = Open3.capture2e(env.merge('CAPTAINS_LOG_EVAL_RUN_DIR' => pipeline), 'bash', "#{Evals::ROOT}/scripts/run-evals.sh", '--pipeline')
    assert.call(status.success?, "pipeline fixture failed: #{output}")
    assert.call(JSON.parse(File.read("#{pipeline}/manifest.json")).length == 5, 'pipeline review did not include every stage')
    assert.call(File.read("#{pipeline}/before-resume.sha256") == File.read("#{pipeline}/after-resume.sha256"), 'resume immutability check lost')
    omitted = "#{run}/omitted-pipeline-artifact"
    output, status = Open3.capture2e(env.merge('CAPTAINS_LOG_EVAL_RUN_DIR' => omitted, 'EVAL_FIXTURE_OMIT_ENRICH' => '1'), 'bash', "#{Evals::ROOT}/scripts/run-evals.sh", '--pipeline')
    assert.call(status.exitstatus == 1 && output.include?('Missing renamed/enriched artifacts'), 'Bash pipeline assertion did not stop for missing output')
    assert.call(!File.file?("#{omitted}/resume.log"), 'pipeline continued after failed artifact assertion')
    combined = "#{run}/all"
    output, status = Open3.capture2e(env.merge('CAPTAINS_LOG_EVAL_RUN_DIR' => combined), 'bash', "#{Evals::ROOT}/scripts/run-evals.sh", '--all')
    assert.call(status.success?, "combined release gate fixture failed: #{output}")
    assert.call(JSON.parse(File.read("#{combined}/manifest.json")).length == 28, 'combined gate dropped pipeline or suite cases')
  ensure
    [saved, focused, combined].compact.each do |saved_run|
      next unless File.file?("#{saved_run}/manifest.json")
      JSON.parse(File.read("#{saved_run}/manifest.json")).each { |item| FileUtils.rm_f(item['output']) }
    end
  end
end
puts "PASS: #{checks} evaluation tooling checks"

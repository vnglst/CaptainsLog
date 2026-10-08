#!/usr/bin/env ruby
require 'yaml'
require 'json'
require 'digest'

# Checks saved model output without altering it. Semantic review remains separate.
module EnrichEvaluation
  KEYS = %w[date recording_time language categories tags persons projects companies entities summary].freeze
  LISTS = %w[categories tags persons projects companies entities].freeze

  def self.validate_case_input!(path, settings)
    return unless settings.key?('sha256')
    expected = settings['sha256']
    raise 'invalid fixture SHA256' unless expected.is_a?(String) && expected.match?(/\A[0-9a-f]{64}\z/)
    raise "regression fixture changed: #{path}" unless Digest::SHA256.file(path).hexdigest == expected
  end

  def self.validate_cases!(manifest, input_dir)
    cases = JSON.parse(File.read(manifest))
    names = Dir.glob(File.join(input_dir, '*.md')).map { |path| File.basename(path, '.md') }
    raise 'case manifest differs from enrichment inputs' unless cases.is_a?(Hash) && cases.keys.sort == names.sort
    cases.each { |name, settings| validate_case_input!(File.join(input_dir, "#{name}.md"), settings) }
  end

  def self.validate!(input, generated, expected)
    match = generated.match(/\A---\r?\n(.*?)\r?\n---\r?\n\r?\n(.*)\z/m)
    raise 'missing YAML frontmatter or body separator' unless match
    yaml, body = match.captures
    raise 'source body changed' unless body == input
    raise 'metadata exceeds 12000 bytes' if yaml.bytesize > 12_000
    stream = Psych.parse_stream(yaml)
    raise 'expected one YAML mapping' unless stream.children.length == 1 && stream.children[0].root.is_a?(Psych::Nodes::Mapping)
    keys = stream.children[0].root.children.each_slice(2).map { |key, _| key.value }
    raise 'duplicate YAML keys' unless keys.uniq == keys
    data = YAML.safe_load(yaml)
    raise 'unexpected or missing schema keys' unless data.keys.sort == KEYS.sort
    %w[date recording_time language summary].each do |key|
      raise "#{key} must be nonempty text" unless data[key].is_a?(String) && !data[key].strip.empty?
    end
    %w[date recording_time].each do |key|
      raise "#{key} differs from supplied value" unless data[key] == expected.fetch(key)
    end
    raise 'summary exceeds 3000 characters' if data['summary'].length > 3_000
    LISTS.each do |key|
      list = data[key]
      raise "#{key} must contain strings" unless list.is_a?(Array) && list.all? { |item| item.is_a?(String) && !item.strip.empty? }
      raise "#{key} exceeds 64 items" if list.length > 64
      names = list.map { |item| item.strip.downcase }
      raise "duplicate #{key}" unless names.uniq == names
    end
    raise 'invalid categories' unless !data['categories'].empty? && (data['categories'] - %w[personal work side-project]).empty?
    raise 'language differs from fixture expectation' unless data['language'].downcase == expected.fetch('language').downcase
    raise 'expected 3 to 8 tags' unless (3..8).cover?(data['tags'].length)
    named = %w[persons projects companies].flat_map { |key| data[key].map { |item| item.strip.downcase } }
    raise 'entity duplicates a person, project or company' unless (named & data['entities'].map { |item| item.strip.downcase }).empty?
    data
  end
end

if __FILE__ == $PROGRAM_NAME
  begin
    if ARGV.length == 3 && ARGV[0] == '--cases'
      EnrichEvaluation.validate_cases!(ARGV[1], ARGV[2])
      puts 'PASS: enrichment case manifest and regression fixture fingerprints'
      exit
    end
    abort 'Usage: validate.rb <input.md> <generated.md> <expected.md> OR --cases <cases.json> <input-dir>' unless ARGV.length == 3
    input, generated, expected = ARGV.map { |path| File.read(path) }
    expected_yaml = expected.match(/\A---\r?\n(.*?)\r?\n---/m)
    raise 'expected file has no frontmatter' unless expected_yaml
    EnrichEvaluation.validate!(input, generated, YAML.safe_load(expected_yaml[1]))
    puts "PASS: enrichment structure, bounds, unique names, date/time and body: #{ARGV[0]}"
  rescue StandardError => error
    warn "FAIL: #{error.message}"
    exit 1
  end
end

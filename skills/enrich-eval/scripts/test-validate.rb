#!/usr/bin/env ruby
require_relative 'validate'
require 'tmpdir'

input = File.read('eval/enrich/input/01_work_week.md')
yaml = File.read('eval/enrich/expected/01_work_week.md').split('---', 3)[1]
expected = YAML.safe_load(yaml)
passed = 0
check = lambda do |name, mutate, failure = nil|
  data = Marshal.load(Marshal.dump(expected))
  body = input.dup
  raw = mutate.call(data, body)
  output = raw || "---\n#{YAML.dump(data).sub(/\A---\n/, '')}---\n\n#{body}"
  begin
    EnrichEvaluation.validate!(input, output, expected)
    raise "#{name}: accepted invalid output" if failure
  rescue StandardError => error
    raise "#{name}: #{error.message}" unless failure && error.message.include?(failure)
  end
  passed += 1
  puts "PASS: #{name}"
end

check.call('valid fixture', ->(_, _) {})
check.call('wrong date', ->(d, _) { d['date'] = '2024-01-01'; nil }, 'date differs')
check.call('wrong time', ->(d, _) { d['recording_time'] = '09:00'; nil }, 'recording_time differs')
check.call('body mutation', ->(_, b) { b << 'added text'; nil }, 'source body changed')
check.call('missing summary', ->(d, _) { d.delete('summary'); nil }, 'schema keys')
check.call('unexpected key', ->(d, _) { d['extra'] = 'text'; nil }, 'schema keys')
check.call('empty summary', ->(d, _) { d['summary'] = ' '; nil }, 'summary must be nonempty')
check.call('repeated summary', ->(d, _) { d['summary'] = 'Repeated sentence. ' * 200; nil }, 'summary exceeds')
check.call('unquoted colon becomes mapping', ->(d, _) { d['entities'] = [{ 'Star Trek' => 'The Next Generation' }]; nil }, 'entities must contain strings')
check.call('scalar list', ->(d, _) { d['projects'] = 'FinanceHub'; nil }, 'projects must contain strings')
check.call('duplicate list item', ->(d, _) { d['projects'] << 'financehub'; nil }, 'duplicate projects')
check.call('cross-field duplicate', ->(d, _) { d['entities'] << 'FinanceHub'; nil }, 'entity duplicates')
check.call('runaway entity list', ->(d, _) { d['entities'] = (1..65).map { |i| "Entity #{i}" }; nil }, 'entities exceeds')
check.call('oversized metadata', ->(d, _) { d['entities'] = ['x' * 12_000]; nil }, 'metadata exceeds')
check.call('invalid category', ->(d, _) { d['categories'] = ['imaginary']; nil }, 'invalid categories')
check.call('empty categories', ->(d, _) { d['categories'] = []; nil }, 'invalid categories')
check.call('legal category differences require semantic review', ->(d, _) { d['categories'] = ['work']; nil })
check.call('wrong language', ->(d, _) { d['language'] = 'Dutch'; nil }, 'language differs')
check.call('too many tags', ->(d, _) { d['tags'] = (1..9).map { |i| "tag-#{i}" }; nil }, '3 to 8 tags')
check.call('duplicate schema key', ->(_, _) { "---\n#{yaml}\nsummary: duplicate\n---\n\n#{input}" }, 'duplicate YAML keys')
check.call('missing completion/body delimiter', ->(_, _) { "---\n#{yaml}" }, 'missing YAML frontmatter')
check.call('multiple YAML documents', ->(_, _) { "---\n#{yaml}\n...\n---\nsummary: second\n---\n\n#{input}" }, 'expected one YAML mapping')
Dir.mktmpdir('enrich-fixture-integrity') do |dir|
  path = File.join(dir, 'fixture.md')
  File.write(path, input)
  manifest = File.join(dir, 'cases.json')
  settings = { 'sha256' => Digest::SHA256.hexdigest(input) }
  File.write(manifest, JSON.generate('fixture' => settings))
  EnrichEvaluation.validate_cases!(manifest, dir)
  passed += 1
  puts 'PASS: recorded fixture fingerprint'

  File.write(path, input + "\n")
  begin
    EnrichEvaluation.validate_cases!(manifest, dir)
    raise 'accepted a reformatted regression fixture'
  rescue StandardError => error
    raise unless error.message.include?('regression fixture changed')
  end
  passed += 1
  puts 'PASS: even a trailing newline changes regression fixture identity'

  File.write(path, input)
  File.write(File.join(dir, 'unlisted.md'), input)
  begin
    EnrichEvaluation.validate_cases!(manifest, dir)
    raise 'accepted an input missing from the case manifest'
  rescue StandardError => error
    raise unless error.message.include?('case manifest differs')
  end
  passed += 1
  puts 'PASS: every input must have recorded case settings'
end
puts "#{passed} enrichment validation checks passed."

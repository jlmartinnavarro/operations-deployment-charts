# frozen_string_literal: true

module Tester
  # Container for a test result
  class TestOutcome
    attr_reader :out, :err, :exit_status, :command
    def initialize(stdout, stderr, exitstatus, cmd)
      @out = stdout
      @err = stderr
      @exit_status = exitstatus
      @command = cmd
    end

    def ok?
      @exit_status.zero?
    end

    def grep_v(pattern)
      @out = @out.split("\n").reject { |l| l =~ pattern }.join("\n") unless @out.nil?
      @err = @err.split("\n").reject { |l| l[pattern] }.join("\n") unless @err.nil?
    end

    def ignore_errors
      @exit_status = 0
    end

    def ==(other)
      return false unless other.is_a?(Tester::TestOutcome)

      (@out == other.out && @err == other.err && @exit_status == other.exit_status && @command == other.command)
    end
  end

  # Specialized outcome for kubeyaml tests.
  class KubeyamlTestOutcome < TestOutcome
    attr_reader :outcomes
    def initialize(command)
      @out = ''
      @err = ''
      @exit_status = 0
      @outcomes = {}
      @command = command
    end

    def add(src, outcome)
      @outcomes[src] ||= []
      @outcomes[src] << outcome
    end

    def ok?
      @outcomes.values.map { |outcomes| outcomes.reject(&:ok?) }.flatten.empty?
    end

    def err
      err = {}
      @outcomes.each do |source, outcomes|
        counter = 0
        outcomes.each do |outcome|
          next if outcome.out.nil?

          err["#{source}[#{counter}]"] = outcome.out
          counter += 1
        end
      end
      err
    end
  end
end
require 'gush/metadata'

module Gush
  class Job
    include Gush::Metadata

    RECURSION_LIMIT = 1000

    DEFAULTS = {
      finished: false,
      enqueued: false,
      failed: false,
      running: false
    }

    attr_accessor :finished, :enqueued, :failed, :workflow_id, :incoming, :outgoing,
      :finished_at, :failed_at, :started_at, :jid, :running

    attr_reader :name

    attr_writer :logger

    def initialize(opts = {})
      options = DEFAULTS.dup.merge(opts)
      assign_variables(options)
    end

    def as_json
      {
        name: @name,
        klass: self.class.to_s,
        finished: @finished,
        enqueued: @enqueued,
        failed: @failed,
        incoming: @incoming,
        outgoing: @outgoing,
        finished_at: @finished_at,
        started_at: @started_at,
        failed_at: @failed_at,
        running: @running
      }
    end

    def to_json(options = {})
      Yajl::Encoder.new.encode(as_json)
    end

    def self.from_hash(hash)
      hash[:klass].constantize.new(
        name:     hash[:name],
        finished: hash[:finished],
        enqueued: hash[:enqueued],
        failed: hash[:failed],
        incoming: hash[:incoming],
        outgoing: hash[:outgoing],
        failed_at: hash[:failed_at],
        finished_at: hash[:finished_at],
        started_at: hash[:started_at],
        running: hash[:running]
      )
    end

    def before_work
    end

    def work
    end

    def after_work
    end

    def start!
      @enqueued = false
      @running = true
      @started_at = Time.now.to_i
    end

    def enqueue!
      @enqueued = true
      @running = false
      @failed = false
      @started_at = nil
      @finished_at = nil
      @failed_at = nil
    end

    def finish!
      @running = false
      @finished = true
      @enqueued = false
      @failed = false
      @finished_at = Time.now.to_i
    end

    def fail!
      @finished = true
      @running = false
      @failed = true
      @enqueued = false
      @finished_at = Time.now.to_i
      @failed_at = Time.now.to_i
    end

    def enqueued?
      !!enqueued
    end

    def finished?
      !!finished
    end

    def failed?
      !!failed
    end

    def succeeded?
      finished? && !failed?
    end

    def running?
      !!running
    end

    def can_be_started?(flow)
      !running? &&
        !enqueued? &&
          !finished? &&
            !failed? &&
              dependencies_satisfied?(flow)
    end

    def dependencies(flow, level = 0)
      fail DependencyLevelTooDeep if level > RECURSION_LIMIT
      (incoming.map {|name| flow.find_job(name) } + incoming.flat_map{ |name| flow.find_job(name).dependencies(flow, level + 1) }).uniq
    end

    def logger
      fail "You cannot log when the job is not running" unless running?
      @logger
    end

    private

    def assign_variables(options)
      @name        = options[:name]
      @finished    = options[:finished]
      @enqueued    = options[:enqueued]
      @failed      = options[:failed]
      @incoming    = options[:incoming] || []
      @outgoing    = options[:outgoing] || []
      @failed_at   = options[:failed_at]
      @finished_at = options[:finished_at]
      @started_at  = options[:started_at]
      @running     = options[:running]
    end

    def dependencies_satisfied?(flow)
      dependencies(flow).all? { |dep| !dep.enqueued? && dep.finished? && !dep.failed? }
    end
  end
end

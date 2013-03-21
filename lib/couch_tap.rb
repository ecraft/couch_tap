
# Low level requirements
require 'sequel'
require 'couchrest'
require 'yajl'

# Our stuff
require 'couch_tap/changes'
require 'couch_tap/document_handler'
require 'couch_tap/table'


module CouchTap
  extend self

  def changes(database, &block)
    changes = Changes.new(database, &block)
    changes.start
  end

  # Provide some way to handle messages
  def logger
    @logger ||= prepare_logger
  end

  def prepare_logger
    log = Logger.new(STDOUT)
    log.level = Logger::INFO
    log
  end

end


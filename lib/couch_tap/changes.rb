
module CouchTap
  class Changes

    attr_reader :source, :database, :schemas, :handlers

    attr_accessor :seq

    # Start a new Changes instance by connecting to the provided
    # CouchDB to see if the database exists.
    def initialize(opts = "", &block)
      raise "Block required for changes!" unless block_given?

      @schemas  = {}
      @handlers = []
      @source   = CouchRest.database(opts)
      info      = @source.info

      logger.info "Connected to CouchDB: #{info['db_name']}"

      # Prepare the definitions
      self.instance_eval(&block)
    end

    # Dual-purpose method, accepts configuration of database
    # or simply returns it.
    def database(opts = nil)
      if opts
        @database ||= Sequel.connect(opts)
        find_or_create_sequence_number
      else
        @database
      end
    end

    def document(filter = {}, &block)
      @handlers << [
        filter,
        DocumentHandler.new(self, &block)
      ]
    end

    def schema(name)
      @schemas[name.to_sym] ||= Schema.new(database, name)
    end

    # Start listening to the CouchDB changes feed.
    # By this stage we should have a sequence id so we know where to start from
    # and all the filters should have been prepared.
    def start
      logger.info "Listening to changes feed..."

      url     = File.join(source.root, '_changes')
      query   = {:since => seq, :feed => 'continuous'}
      @http   = EventMachine::HttpRequest.new(url).get(:query => query)
      @parser = Yajl::Parser.new
      @parser.on_parse_complete = method(:process_row)

      @http.stream {|chunk| @parser << data}
    end

    protected

    def process_row(row)
      if row['deleted']
        logger.info "Received delete seq. #{row['seq']} id: #{row['id']}"

        # Not sure what to do with this yet!

      else
        logger.info "Received change seq. #{row['seq']} id: #{row['id']}"
        doc = fetch_document(row['id'])
        handler = find_document_handler(doc)
        handler.execute(doc) if handler
      end

      update_sequence(row['seq'])
    end

    def fetch_document(id)
      source.get(row['id'])
    end

    def find_document_handler(document)
      handler = nil
      @handlers.each do |row|
        row[0].each do |k,v|
          handler = (document[k.to_s] == v ? row[1] : nil)
        end
      end
      handler
    end

    def find_or_create_sequence_number
      create_sequence_table unless database.table_exists?(:couch_sequence)
      self.seq = database[:couch_sequence].where(:name => source.name).first[:seq]
    end

    def update_sequence(seq)
      database[:couch_sequence].where(:name => source.name).update(:seq => seq)
      self.seq = seq
    end

    def create_sequence_table
      database.create_table :couch_sequence do
        String :name, :primary_key => true
        Bignum :seq, :default => 0
        DateTime :created_at
        DateTime :updated_at
      end
      # Add first row
      database[:couch_sequence].insert(:name => source.name)
    end

    def logger
      CouchTap.logger
    end

  end
end

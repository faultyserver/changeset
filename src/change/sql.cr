module Change
  # This is an incredibly basic module for SQL generation. To start, I just
  # need a way of querying, inserting, updating, and deleting. No corner cases,
  # associations, or anything like that are intended to be supported by this
  # basic implementation.
  #
  # Expanding this into a proper DSL/querying library can come later (see
  # `query-ideas.cr` for an example of what this may look like in the future).
  module SQL
    # Define the name of the source table for an object.
    macro source(name)
      class_getter sql_source = "{{name.id}}"
    end
  end

  module Repo
    def self.all(conn, queryable : T.class) : Array(T) forall T
      source = queryable.sql_source
      columns = T::Changeset::FIELD_NAMES.map{ |field| "#{source}.#{field}" }
      select_string = columns.join(", ")

      queryable.from_rs(conn.query("SELECT #{select_string} FROM #{source}"))
    end

    def self.insert(conn, changeset : Changeset(T, U)) forall T, U
      return unless (changeset.valid?)

      source = T.sql_source

      fields = [] of String
      values = [] of String
      changeset.each_field do |field, value|
        fields.push(field)
        values.push(value.inspect)
      end

      query = <<-SQL
        INSERT INTO #{source} (#{fields.join(", ")})
        VALUES (#{values.join(", ")})
      SQL

      query
    end
  end
end

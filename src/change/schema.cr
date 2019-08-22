module Change
  macro included
    struct Changeset < ::Change::Changeset({{@type}})
      FIELDS = [] of NamedTuple(name: String, type: String)
    end

    macro finished
      gen_schema(\{{@type}})
    end
  end


  macro field(prop, **opts)
    {% Changeset::FIELDS.push({name: prop.var, type: prop.type}) %}
    property! {{prop}}?
  end

  macro field!(prop, **opts)
    {% Changeset::FIELDS.push({name: prop.var, type: prop.type}) %}
    property {{prop}}
  end


  # Generate a custom Changeset struct for the given type. `properties` will
  # also be generated as properties on the type itself.
  # `properties` should not include any nilable types, as they will be added
  # automatically on generation. By default, normal accessors will be non-
  # nilable, and query accessors (e.g. `name?`) can be used if a nil value may
  # be expected.
  #
  # Rather than enforcing nilability on the field type itself, it is instead
  # managed by the Changeset's casting, validations, and other constraints.
  macro gen_schema(type)
    {% prop_names = Changeset::FIELDS.map(&.[:name]) %}
    {% prop_types = Changeset::FIELDS.map(&.[:type]) %}

    struct Changeset < ::Change::Changeset({{type}})
      {% for prop in Changeset::FIELDS %}
        property! {{prop[:name].id}} : {{prop[:type].id}}?
        property? {{prop[:name].id}}_changed : Bool = false
      {% end %}

      FIELD_NAMES = {{ prop_names.map(&.stringify) }}

      def changed? : Bool
        {% for prop in prop_names %}
          return true if self.{{prop}}_changed?
        {% end %}

        return false
      end

      def has_field?(field : String) : Bool
        FIELD_NAMES.includes?(field)
      end

      def get_change(field : String, default=nil)
        case field
          {% for prop in prop_names %}
            when "{{prop}}"
              return self.{{prop}}? if self.{{prop}}_changed?
              return default
          {% end %}
        end
      end

      def get_field(field : String, default=nil)
        case field
          {% for prop in prop_names %}
            when "{{prop}}"
              return self.{{prop}}? if self.{{prop}}_changed?
              existing = @instance.{{prop}}?
              return existing.nil? ? default : existing
          {% end %}
        end
      end

      def apply_changes : {{type}}
        {% for prop in prop_names %}
          if self.{{prop}}_changed?
            @instance.{{prop}} = self.{{prop}}?
          end
        {% end %}

        @instance
      end

      def apply_changes(inst : {{type}}) : {{type}}
        {% for prop in prop_names %}
          if self.{{prop}}_changed?
            inst.{{prop}} = self.{{prop}}?
          end
        {% end %}

        inst
      end

      def changes_hash : Hash(String, String?)
        hash = {} of String => String?
        {% for prop in prop_names %}
          if self.{{prop}}_changed?
            hash["{{prop}}"] = self.{{prop}}?.try(&.to_s)
          end
        {% end %}
        hash
      end

      protected def cast_field(field : String, value)
        case field
        {% for prop in Changeset::FIELDS %}
          when "{{prop[:name].id}}"
            valid, value = Change::TypeCast.cast(value, {{prop[:type].id}})
            return if @instance.{{prop[:name].id}}? == value

            if valid
              self.{{prop[:name].id}} = value
              self.{{prop[:name].id}}_changed = true
            else
              self.valid = false
            end
        {% end %}
        end
      end
    end
  end
end

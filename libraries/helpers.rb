module Opsline
  module GoApp
    module Helpers



      def to_bool(value)
        return true if value == true || value =~ (/^(true|t|yes|y|1)$/i)
        return false if value == false || value.empty? || value =~ (/^(false|f|no|n|0)$/i)
        raise ArgumentError.new("invalid value for Boolean: \"#{value}\"")
      end

      def get_env_value(element)
        if element.is_a?(Hash)
          if element.has_key?(node.chef_environment)
            element[node.chef_environment]
          elsif element.has_key?('default')
            element['default']
          else
            {}
          end
        else
          element
        end
      end


    end
  end
end

# frozen_string_literal: true

module Irasutoya
  module Modules
    module DualLevel
      def self.included(klass)
        super
        klass.extend(ClassMethods)
      end

      module ClassMethods
        def included(klass)
          super
          klass.send(:include, const_get(:Methods))
          klass.send(:extend, const_get(:Methods))
        end
      end
    end
  end
end

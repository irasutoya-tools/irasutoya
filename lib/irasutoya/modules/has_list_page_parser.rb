# frozen_string_literal: true

module Irasutoya
  module Modules
    module HasListPageParser
      def self.included(klass)
        super
        klass.send(:include, Irasutoya::Modules::HasListPageParser::Methods)
        klass.send(:extend, Irasutoya::Modules::HasListPageParser::Methods)
      end

      module Methods
        def parse_list_page(document:)
          document.css('.box').map do |box|
            {
              title: PrivateMethods.title_from(box: box),
              show_url: PrivateMethods.show_url_from(box: box)
            }
          end
        end
      end

      module PrivateMethods
        class << self
          def title_from(box:)
            box.css('a')[1].text
          end

          def show_url_from(box:)
            box.css('a').first.attribute('href').value
          end
        end
      end
    end
  end
end

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
            anchors = box.css('a')
            {
              title: anchors[1].text,
              show_url: anchors.first.attribute('href').value
            }
          end
        end
      end
    end
  end
end

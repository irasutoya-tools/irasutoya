# frozen_string_literal: true

module Irasutoya
  class Irasuto
    attr_reader :url, :title, :description, :image_url

    def initialize(url:, title:, description:, image_url:)
      @url = url
      @title = title
      @description = description
      @image_url = image_url
    end
  end
end

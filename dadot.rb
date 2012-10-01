# -*- coding: utf-8 -*-
require 'erb'
require 'gviz'
require 'open-uri'
require 'rexml/document'

class Dadot
  REQUEST_URI = 'http://jlp.yahooapis.jp/DAService/V1/parse'

  def initialize(app_id)
    @app_id = app_id
  end

  def run(text)
    gv   = Gviz.new
    data = parse(request(text.to_s))

    gv.graph do
      data.each do |id, text, dep|
        route id => dep unless dep == :"-1"
        node id, label: text
      end
    end

    gv.save(:pref, :png)
  end

  private

  #
  # @see http://developer.yahoo.co.jp/webapi/jlp/da/v1/parse.html
  #
  # @param [String] text 係り受け解析する文字列
  # @return [String] 解析結果 (XML)
  #
  def request(text)
    query = "appid=#{app_id}&sentence=#{url_encode(text.chomp)}"

    begin
      response = open("#{REQUEST_URI}?#{query}")
    rescue OpenURI::HTTPError => e
      response = e.io
    rescue e
      throw e
    end

    xml = response.read
    response.close
    xml
  end

  #
  # @param [String] 日本語係り受け解析 (XML)
  #
  # @return [Array]
  #   parse したオブジェクトの配列
  #     obj[:id]   => 文節の番号
  #     obj[:text] => 文節の文字列
  #     obj[:dep]  => この文節の係り受け先
  #
  def parse(xml)
    doc = REXML::Document.new(xml)

    if !doc.elements['/Error/Message'].nil?
      return [[
          :"1",
          doc.elements['/Error/Message'].get_text.to_s.gsub("\n", ""),
          :"-1"
        ]]
    end

    chunk_list = []

    doc.each_element('ResultSet/Result/ChunkList/Chunk') do |chunk|
      chunk_list << [
        chunk.get_text('Id').to_s.to_sym,
        chunk.get_elements('MorphemList/Morphem/Surface').map(&:text).join,
        chunk.get_text('Dependency').to_s.to_sym
      ]
    end

    chunk_list
  end

  def app_id
    url_encode(@app_id)
  end

  def url_encode(text)
    ERB::Util.url_encode(text)
  end
end

if __FILE__ == $0
  dadot = Dadot.new('Your Application ID')
  dadot.run(ARGV[0])
end

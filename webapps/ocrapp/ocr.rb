#!/usr/bin/env ruby
#
# Service to query hOCR coordinates from Solr and return
# results in JSON format.
#
# Author: Rasan Rasch <rasan@nyu.edu>

require 'rubygems'
require 'sinatra'
require 'rsolr'
require 'json'
require 'uri'

get '/regions' do

  $stderr.puts params.inspect
  
  uri = URI.parse(params[:targetUri])
  terms = params[:searchTerms]
  callback = params[:callback]

  terms = terms.gsub(/\s+/, " OR ")

  want_openlayers_coords = params[:coordFormat] == "openLayers"

  empty_str, collection, type, item_id, seq_num = uri.path.split("/")

  results = []

  solr = RSolr.connect :url => 'http://localhost:8080/solr_ocr'

  query = "word:(#{terms}) collection:#{collection} item_id:#{item_id} seq_num:#{seq_num}"

  $stderr.puts query

  search = solr.get 'select', :params => {:q => query}

  search["response"]["docs"].each do |doc|
    word = doc["word"]
    $stderr.puts doc["seq_num"]
    if want_openlayers_coords
      coordinates = doc["openlayers_coords"].split
    else
      coordinates = doc["tesseract_coords"].split
    end
    results.push({"term" => word, "coordinates" => coordinates})
  end 
  
  json = {"terms" => results}.to_json
  
  if callback
    content_type :js
    response = "#{callback}(#{json})"
  else
    content_type :json
    response = json
  end

  response
end


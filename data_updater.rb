#!/usr/bin/env ruby

require 'mysql2'
require 'nokogiri'
require 'open-uri'

# Populate a MYSQL database with song data from Tunebat
class DataUpdater
  attr_reader :artist, :title, :id, :backlog

  def run
    system 'clear'
    songs = remove_already_processed(songlist)
    @backlog = songs.count
    puts "-==[#{@backlog}]==- songs to go!"
    songs.each { |i, a, t| update_song(i, a, t) }
  end

  private

  def remove_already_processed(songs)
    pruned = []
    songs.each do |song|
      next if processed_ids.include? song.first
      pruned << song
    end
    pruned
  end

  def filename
    'processed.songs'
  end

  def processed_ids
    File.readlines(filename).map(&:to_i)
  end

  def update_song(id, artist, title)
    @id = id
    @artist = artist
    @title = title
    update_data
    add_to_list(id)
  end

  def add_to_list(id)
    File.open(filename, 'a') { |f| f.puts(id) }
  end

  def songlist(list = [])
    sql = 'SELECT ID, title, artist FROM songlist ' \
          "WHERE songtype = \'S\' AND happiness = 0"
    results = client.query(sql)
    results.each { |s| list << [s['ID'], s['artist'].to_s, s['title']] }
    list
  end

  def xpath(doc, name)
    doc.xpath(paths[name.to_sym]).children.to_s
  end

  def lookup_data
    pause
    base_url = 'https://tunebat.com'
    path = '/Search?q=' + (artist + ' ' + title).tr(' ', '+')
    doc = Nokogiri::HTML(open(base_url + sanitize(path)))
    path_to_link = '/html/body/div[1]/div[1]/div/' \
                   'div/div[2]/div[2]/div[1]/div/a'
    link_data = doc.xpath(path_to_link).first
    return unless link_data
    link = link_data.attributes['href'].value
    doc = Nokogiri::HTML(open(base_url + link))
    data = {}
    paths.keys.each { |a| data[a] = xpath(doc, a) }
    data
  rescue => error
    puts error.message
  end

  def paths
    { happiness: '/html/body/div[1]/div[2]/div/div/div[1]/div/div/div/div[3]/div/div[1]/table/tbody/tr[2]/td[3]',
      danceability: '/html/body/div[1]/div[2]/div/div/div[1]/div/div/div/div[3]/div/div[1]/table/tbody/tr[2]/td[2]',
      energy: '/html/body/div[1]/div[2]/div/div/div[1]/div/div/div/div[3]/div/div[1]/table/tbody/tr[2]/td[1]',
      accousticness: '/html/body/div[1]/div[2]/div/div/div[1]/div/div/div/div[3]/div/div[1]/table/tbody/tr[2]/td[5]', 
      instrumentalness: '/html/body/div[1]/div[2]/div/div/div[1]/div/div/div/div[3]/div/div[1]/table/tbody/tr[2]/td[6]', 
      liveness: '/html/body/div[1]/div[2]/div/div/div[1]/div/div/div/div[3]/div/div[1]/table/tbody/tr[2]/td[7]',
      speechiness: '/html/body/div[1]/div[2]/div/div/div[1]/div/div/div/div[3]/div/div[1]/table/tbody/tr[2]/td[8]',
      album: '/html/body/div[1]/div[2]/div/div/div[1]/div/div/div/div[2]/table/tbody/tr[2]/td[2]' }
  end

  def update_data
    @backlog -= 1
    data = lookup_data
    puts "#{artist} - #{title}"
    return unless data
    settings = ''
    paths.keys.each { |a| settings += "#{a} = '#{data[a.to_sym]}', " }
    sql = "UPDATE songlist SET #{settings[0..-3]} WHERE id = #{id}"
    puts data.to_s
    client.query(sql)
  rescue => error
    puts "Skipping #{artist} - #{title}\n#{error.message}"
  end

  def sanitize(string)
    string.gsub(/[\u0080-\u00ff]/, '')
  end

  def pause
    sleep 10
  end

  def options
    { host: ENV['DB_HOST'],
      username: ENV['DB_USER'],
      password: ENV['DB_PWD'],
      database: ENV['DB_DB'] }
  end

  def client
    @client ||= Mysql2::Client.new(options)
  end
end

DataUpdater.new.run

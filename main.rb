require_relative "./product.rb"
require 'nokogiri'
require 'open-uri'
require 'redis'

class Main
  def initialize
    @redis = Redis.new(host: "localhost")
  end

  def run
    puts "== Start init page =="
    doc = Nokogiri::HTML(URI.open('https://magento-test.finology.com.my/breathe-easy-tank.html'))
    puts "-Get Menus-"
    menus = get_menus(doc)
    menus = has_pagination(menus)
    collect_datas_menus(menus)
    puts "== Done =="
  end

  def get_menus(doc)
    doc.css('nav.navigation ul li a').each do |t|
      next if @redis.smembers('menus').include?(t['href'])
      puts "-save menu to cache #{t['href']}"
      @redis.sadd('menus', [t['href']])
    end
    return @redis.smembers('menus')
  end

  def has_pagination(menus)
    puts "-check the page if has records"
    menus.each do |menu|
      next if @redis.smembers('ignore_url').include?(menu) || @redis.smembers('valid_urls').include?(menu)
      puts "-check page #{menu}"
      doc = Nokogiri::HTML(URI.open(menu))
      pagination = doc.css('ul.pages-items li.item a.page')
      ignore_unnecessary_url(menu) if pagination.empty?
      add_urls(menu) unless pagination.empty?
    end
    return @redis.smembers('valid_urls')
  end

  def collect_datas_menus(menus)
    menus.each do |menu|
      puts "-init collect data from #{menu}"
      collect_datas(menu)
    end
  end

  def collect_datas(menu)
    doc = Nokogiri::HTML(URI.open(menu))
    pagination = doc.css('ul.pages-items li.item a.page')
    last_page = pagination.last['href']
    last_number = last_page.gsub("#{menu}?p=", '').to_i
    (1..last_number).each do |per_page|
      puts "-collect from page #{menu}?p=#{per_page}"
      collect_data_per_page("#{menu}?p=#{per_page}")
    end
  end

  def collect_data_per_page(url)
    puts "-collect data from #{url}"
    doc = Nokogiri::HTML(URI.open(url))
    doc.css('.products-grid ol li .product-item-info a.product').each do |item|
      next if @redis.smembers('ignore_url').include?(item['href'])
      insert_data(item['href'])
    end

  end

  def insert_data(data)
    extra = []
    doc = Nokogiri::HTML(URI.open(data))
    name = doc.css('.page-title span').text
    price = doc.css('.price-box span.price').first.text.gsub("$", "").to_f
    description = doc.css('.product.attribute.description').text.strip.gsub('\n', '')
    doc.css('.additional-attributes-wrapper.table-wrapper tbody tr').each do |tr|
      extra << "#{tr.at('th').text}: #{tr.at('td').text}"
    end
    extra_description = extra.join(' | ')
    post_data = post_data([name, price, description, extra_description])
    puts "-insert data #{data}"
    if post_data
      @redis.sadd('ignore_url', data)
    end
  end

  def post_data(params)
    name = params.first
    unless Product.exists?(name)
      Product.create(params)
    end
    return true
  end

  def ignore_unnecessary_url(url)
    @redis.sadd('ignore_url', url)
  end

  def add_urls(url)
    @redis.sadd('valid_urls', url)
  end
end

Main.new.run()

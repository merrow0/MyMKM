require "rubygems"
require "nokogiri"
require "sinatra"
require "open-uri"
require "net/https"

BASE_MKM_URL = "https://www.magickartenmarkt.de"
api_url = ""

enable :sessions

get "/" do
  @title = "Main"
	
	if api_url.length > 0
		@msg = "Angemeldet, herzlich Willkommen."
	else
		@msg = "Nicht angemeldet, somit nur die Suche moeglich."
	end
	
	erb :index
end

get "/login" do
  @title = "Login"
  erb :login
end

post "/login" do
	require "mechanize"
	
  agent = Mechanize.new
  agent.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  
  page = agent.get("#{BASE_MKM_URL}")
  login_form = page.forms[1]

  unless login_form.nil?
    login_form["username"] = params[:user]
    login_form["userPassword"] = params[:pass]
    login_form.submit
  end

  page = agent.get("#{BASE_MKM_URL}/?mainPage=showMyAccount")
  api_key = page.parser.css(".myAccountPersonalData-table a")[1].text unless page.parser.css(".myAccountPersonalData-table a")[1].nil?

  unless api_key.nil?
    api_url = "https://www.mkmapi.eu/ws/#{params[:user]}/#{api_key}"
  else
    redirect to "/login"
  end

  redirect to "/"
end


get "/search" do
  @title = "Suche"
	
  erb :search
end

post "/result" do
  card = params[:searchStr]
  @title = "Suchergebnis für '#{card}'"

  card = card.gsub(" ", "%20")
  @resList = []
  
  xml = Nokogiri::XML(open("https://www.mkmapi.eu/ws/stevinyl/c4076bff0dc81ba0d93d858081a0c513/products/#{card}/1/1/false", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))

  xml.css("product").each do |product|
    prodHash = {}
    
    unless product.at_css("idProduct").nil?
      prodHash["idProduct"] = product.at_css("idProduct").text
      prodHash["productName"] = product.at_css("name productName").text
      prodHash["priceGuide"] = "Low:#{product.at_css("priceGuide LOW").text}€  /  Avg:#{product.at_css("priceGuide AVG").text}€"
      prodHash["expansion"] = product.at_css("expansion").text
      prodHash["rarity"] = product.at_css("rarity").text unless product.at_css("rarity").nil?
      prodHash["image"] = product.at_css("image").text[1..-1]
    end

    @resList.push(prodHash)
  end

  erb :result
end
=begin
get "/card/:cardId" do
  @title = "Karte"
  erb :card, :layout => false
end
=end
before "/wants" do
  if api_url.length == 0
    redirect to "/login"
  end
end

get "/wants" do
  @title = "Wants"
  @wantsList = []
  
  xml = Nokogiri::XML(open("#{api_url}/wantslist", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))
  
  xml.css("wantsList").each do |want|
    wantHash = {}
    
    wantHash["idWantsList"] = want.at_css("idWantsList").text
    wantHash["name"] = want.css("name")[1].text
    wantHash["itemCount"] = want.at_css("itemCount").text
    
    @wantsList.push(wantHash)
  end
  
  erb :wants
end

get "/want/:wantId" do
  @title = "Karten von "
  @wantList = []
  
  xml = Nokogiri::XML(open("#{api_url}/wantslist/#{params[:wantId]}", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))
  
  xml.css("want").each do |want|
    wantHash = {}
    
    wantHash["idWant"] = want.at_css("idWant").text
    wantHash["idMetaproduct"] = want.at_css("idMetaproduct").text
    wantHash["type"] = want.at_css("type").text
    wantHash["amount"] = want.at_css("amount").text
    
    mcard_xml = Nokogiri::XML(open("#{api_url}/metaproduct/#{wantHash["idMetaproduct"]}", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))
    wantHash["productName"] = mcard_xml.at_css("name metaproductName")
    
    @wantList.push(wantHash)
  end
  
  erb :want
end

get "/want/:metaId/detail" do
  mcard_xml = Nokogiri::XML(open("#{api_url}/metaproduct/#{params[:metaId]}", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))
  
  @title = "Details von #{mcard_xml.at_css("metaproduct metaproductName").text}"
  @resList = []
    
  productHash = {}

  mcard_xml.css("products idProduct").each do |product|
    productHash = {}
    
    card_xml = Nokogiri::XML(open("#{api_url}/product/#{product.text}", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))
    productHash["idProduct"] = card_xml.at_css("idProduct").text
    productHash["productName"] = card_xml.at_css("name productName").text
    productHash["priceGuide"] = "Low:#{card_xml.at_css("priceGuide LOW").text}€  /  Avg:#{card_xml.at_css("priceGuide AVG").text}€"
    productHash["expansion"] = card_xml.at_css("expansion").text
    productHash["rarity"] = card_xml.at_css("rarity").text unless card_xml.at_css("rarity").nil?
    productHash["image"] = card_xml.at_css("image").text[1..-1]
    
    @resList.push(productHash)
  end
  
  erb :result
end

before "/orders/:actor" do
  if api_url.length == 0
    redirect to "/login"
  end
end

get "/orders/:actor" do
  actor = params[:actor]
  @title = actor == "1" ? "Verkäufe" : "Einkäufe"
  
  @boughtList = []
  bought_xml = Nokogiri::XML(open("#{api_url}/orders/#{actor}/1", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))
  bought_xml.css("order").each do |order|
    unless order.at_css("seller").nil?
      hash = {}
      
      hash["seller"] = order.at_css("seller").text
      hash["buyer"] = order.at_css("buyer").text
      hash["article"] = order.at_css("article").text
      hash["articleValue"] = order.at_css("articleValue").text
      hash["totalValue"] = order.at_css("totalValue").text
      
      @boughtList.push(hash)
    end
  end
  
  @paidList = []
  paid_xml = Nokogiri::XML(open("#{api_url}/orders/#{actor}/2", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))
  paid_xml.css("order").each do |order|
    unless order.at_css("seller").nil?
      hash = {}
      
      hash["seller"] = order.at_css("seller").text
      hash["buyer"] = order.at_css("buyer").text
      hash["article"] = order.at_css("article").text
      hash["articleValue"] = order.at_css("articleValue").text
      hash["totalValue"] = order.at_css("totalValue").text
      
      @paidList.push(hash)
    end
  end
  
  
  @sentList = []
  sent_xml = Nokogiri::XML(open("#{api_url}/orders/#{actor}/4", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))
  sent_xml.css("order").each do |order|
    unless order.at_css("seller").nil?
      hash = {}
      
      hash["seller_username"] = order.at_css("seller username").text
      hash["buyer username"] = order.at_css("buyer username").text
      hash["articleValue"] = order.at_css("articleValue").text
      hash["totalValue"] = order.at_css("totalValue").text
      
      hash["articles"] = {}
      order.css("article").each do |article|
        hash["articles"]["idProduct"] = article.at_css("idProduct").text
        hash["articles"]["price"] = article.at_css("price").text
        hash["articles"]["count"] = article.at_css("count").text
      end
      
      @sentList.push(hash)
    end
  end
  
  erb :orders
end


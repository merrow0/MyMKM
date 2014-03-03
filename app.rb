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
		@msg = "Nicht angemeldet, somit nur die Suche möglich."
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
  page = agent.get("#{BASE_MKM_URL}", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE)
  login_form = page.forms[1]

  unless login_form.nil?
    login_form["username"] = params[:user]
    login_form["userPassword"] = params[:pass]
    login_form.submit
  end

  page = agent.get("#{BASE_MKM_URL}/?mainPage=showMyAccount", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE)
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
  @title = "Suchergebnis fuer #{card}"

  card = card.gsub(" ", "%20")
  @resList = []
  
  xml = Nokogiri::XML(open("#{api_url}/products/#{card}/1/1/false", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))

  xml.css("product").each do |product|
    prodHash = {}
    
    unless product.at_css("idProduct").nil?
      prodHash["idProduct"] = product.at_css("idProduct").text
      prodHash["productName"] = product.at_css("name productName").text
      prodHash["priceGuide"] = "Low:#{product.at_css("priceGuide LOW").text} Avg:#{product.at_css("priceGuide AVG").text}"
      prodHash["expansion"] = product.at_css("expansion").text
      prodHash["rarity"] = product.at_css("rarity").text unless product.at_css("rarity").nil?
      prodHash["image"] = product.at_css("image").text[1..-1]
    end

    @resList.push(prodHash)
  end

  erb :result
end

get "/card/:cardId" do
  @title = "Karte"
  erb :card, :layout => false
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
    wantHash["productName"] = mcard_xml.at_css("metaproduct metaproductName").text
    
    productHash = {}

    mcard_xml.css("products idProduct").each do |product|
      card_xml = Nokogiri::XML(open("#{api_url}/product/#{product.text}", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))
      productHash["priceGuide"] = card_xml.at_css("priceGuide").text
      productHash["expansion"] = card_xml.at_css("expansion").text
      productHash["image"] = card_xml.at_css("image").text
    end

    wantHash["idProducts"] = productHash

    @wantList.push(wantHash)
  end
  
  erb :want
end

require "sinatra"
require "sinatra/basic_auth"

# Specify your authorization logic
authorize do |username, password|
  (username == "john" && password == "steffen") or (username == "steffen" && password == "l")
end

get "/" do
  "Free world"
end

# Set protected routes
protect do
  get "/admin" do
    "Restricted page that only admin can access"
    "Hello, #{auth.credentials}"
  end
end
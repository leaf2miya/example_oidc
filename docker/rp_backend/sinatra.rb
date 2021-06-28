require 'rubygems'
require 'sinatra'
require 'faraday'
require 'json'
require 'jwt'

class SinatraApp < Sinatra::Base
  CommunicationError = Class.new(StandardError)
  TokenExpireError = Class.new(StandardError)
  RequiredScopeError = Class.new(StandardError)
  UnknownUserError = Class.new(StandardError)
  ParameterError = Class.new(StandardError)

  configure do
    set :bind, '0.0.0.0'
    set :port, 3000
    set :inline_template, true
    $stdout.sync = true # debug
  end

  before '/api*' do
    @conn = Faraday.new(url: ENV['BASE_URL']) do |conn|
      conn.request :url_encoded
      conn.response :logger
      conn.adapter Faraday.default_adapter
    end
  end

  before '/api*' do
    # get token
    # Three ways to receive token (from RFC6750)
    # Authorization Header (RFC6750 2.1)
    # access_token form parameter (RFC6750 2.2)
    # access_token query parameter (RFC6750 2.2)
    @access_token = if request.env['HTTP_AUTHORIZATION']
                      # format: Bearer <token>
                      if matcher = request.env['HTTP_AUTHORIZATION'].match(/\ABearer (\S+)/)
                        matcher[1]
                      end
                    elsif params[:access_token]
                      params[:access_token]
                    else
                      raise ParameterError, "not found: access_token"
                    end
  end

  helpers do
    def call_introspection_endpoint(token)
      res = @conn.post do |req|
        req.url ENV['INTROSPECTION_ENDPOINT_PATH']
        req.body = {
          token: token,
          token_type_hint: 'access_token',
          client_id: ENV['IDENTIFIER'],
          client_secret: ENV['SECRET']
        }
      end
      p res
      if res.status == 200
        json = JSON.parse(res.body)
        raise TokenExpireError, "token expired" if json['active'] == false
        json
      else
        raise CommunicationError, "HTTP Status: #{res.status}"
      end
    end

    def verify(token, required_scopes: [:openid])
      # token valid check
      raise TokenExpireError, "token expired" unless token['active']
      # scope check
      scopes = token['scope'].split(' ').map(&:to_sym)
      raise RequiedScopeError, "does'n have #{require_scopes}" unless (required_scopes - scopes).empty?
      # user check
      uid = token['sub']
      # Check if the token user is registered in the application (e.g., DB table lookup)
      # raise UknownUserError, "Uknown User: #{uid}" if ...
    end
  end

  get '/' do
    'Hello Sinatra!'
  end

  post '/api' do
    json_token = call_introspection_endpoint(@access_token)
    # verify token
    verify(json_token)
    "call api"
  rescue => e
    e.message
  end
end

SinatraApp.run! if __FILE__ == $0

FROM ruby:2.7.3

WORKDIR /myapp
COPY ./Gemfile .
COPY ./Gemfile.lock .
COPY sinatra.rb .

RUN apt-get update
RUN bundle config set path 'vendor'
RUN bundle install

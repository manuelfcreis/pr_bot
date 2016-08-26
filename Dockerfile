FROM ruby:2.3-alpine
MAINTAINER andruby

# Needed to build eventmachine
RUN apk update && apk add g++ musl-dev make && rm -rf /var/cache/apk/*

RUN mkdir -p /var/www/pr_bot
WORKDIR /var/www/pr_bot
COPY Gemfile .
COPY Gemfile.lock .
RUN bundle install
COPY app.rb .

ENV BIND 0.0.0.0
EXPOSE 4567

CMD bundle exec ruby app.rb


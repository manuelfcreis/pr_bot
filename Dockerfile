FROM ruby:2.6.3-alpine

# Needed to build eventmachine
RUN apk upgrade --no-cache && \
    apk add --no-cache g++ musl-dev make

RUN mkdir -p /var/www/pr_bot
WORKDIR /var/www/pr_bot

COPY Gemfile Gemfile.lock ./
RUN bundle install
COPY app.rb .
COPY lib/ lib/

ENV BIND 0.0.0.0
EXPOSE 4567

CMD ["bundle", "exec", "ruby", "app.rb"]

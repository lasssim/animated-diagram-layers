FROM ruby:2.7.2

# Install dependencies
WORKDIR /usr/bin

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      bc \
      ffmpeg \
      gifsicle \
    && wget -q -O 3Drotate "http://www.fmwconcepts.com/imagemagick/downloadcounter.php?scriptname=3Drotate&dirname=3Drotate" \
    && chmod +x 3Drotate

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

CMD ["ruby", "./main.rb"]
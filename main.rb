require 'dotenv/load'
require 'sinatra'
require 'telegram/bot'
require 'rest-client'
require 'date'

class Main < Sinatra::Base
  configure do
    set :bot, Telegram::Bot::Client.new(ENV['TELEGRAM_BOT_TOKEN'])
  end

  get '/' do
    'hello world!'
  end

  post '/message/{token}' do
    raise 'Wrong Token' if params[:token] != ENV['TELEGRAM_BOT_TOKEN']
    reply = ''
    update = JSON.parse(request.body.read)
    if update['message']
      message = update['message']
      puts message.to_s
      reply = do_something_with_text(message['text'], message['from']['username'])
      settings.bot.api.send_message(chat_id: message['chat']['id'], text: reply, reply_to_message_id: message['message_id'])
    end
    200
    # content_type :json
    # reply.to_json
  end

  def do_something_with_text(text, username)
    reply = text
    splitted_text = text.split
    command = splitted_text[0]

    if command == '/today'
      reply = fetch_todays_event()
    elsif command == '/remote' || command == '/leave'
      reply = create_event(text, command)
    elsif command == '/help'
      reply = "/remote <telegram username> <start_date> <end_date> - Create remote event\n" +
              "/leave <telegram username> <start_date> <end_date> - Create leave event\n"
    end
    reply# return
  end

  def fetch_todays_event()
    reply = 'Tidak ada event hari ini'
    response = RestClient::Request.execute(
      method: :get,
      url: "https://api.teamup.com/#{ENV['TEAMUP_CALENDAR_ID']}/events",
      headers: {'Teamup-Token': "#{ENV['TEAMUP_TOKEN']}"}
    )
    response = JSON.parse(response.body)
    events = response['events']

    if !events.empty? 
      message = "List event hari ini: \n"
      events.each do | event |
        message += "- #{event['title']}"
        message += "#{event['who'].empty? ? '' : " - #{event['who']}" }\n"
      end
      reply = message
    end
    reply
  end

  def create_event(text, event)
    reply = "Format salah"
    splitted_text = text.split
    if splitted_text.count == 4
      name = splitted_text[1]
      start_date = splitted_text[2]
      end_date = splitted_text[3]
      begin
        start_date = Date.parse(start_date).strftime("%Y-%m-%d")
        end_date = Date.parse(end_date).strftime("%Y-%m-%d") 

        post_params = { 
          "subcalendar_id" => 2640452,
          "start_dt" => start_date,
          "end_dt" => end_date,
          "all_day" => true,
          "rrule" => "",
          "title" => "#{event == remote ? 'Remote' : 'Cuti'}",
          "who" => name,
          "location" => "",
          "notes" => ""
        }

        response = RestClient::Request.execute(
          method: :post,
          url: "https://api.teamup.com/#{ENV['TEAMUP_CALENDAR_ID']}/events",
          payload: post_params.to_json,
          headers: {'Teamup-Token': "#{ENV['TEAMUP_TOKEN']}", 'Content-type': 'application/json'}
        )
        reply = "#{response.code == 201 ? 'Event berhasil dibuat' : 'Event gagal dibuat'}"

        # reply = post_params

      rescue ArgumentError  
        reply = 'Format tanggal mulai atau selesai salah'
      end
    end
    reply
  end
end

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
      puts(message)
      do_something_with_text(message)
    end
    200
    # content_type :json
    # reply.to_json
  end

  def do_something_with_text(message)
    reply = ''
    splitted_text = message['text'].split
    command = splitted_text[0]

    if command.include? '/today'
      reply = fetch_todays_event(message)
    elsif (command.include? '/remote') || (command.include? '/leave')
      reply = create_event(text, command)
    elsif command.include? '/help'
      reply = "/remote <telegram username> <start_date> <end_date> - Create remote event\n" +
              "/leave <telegram username> <start_date> <end_date> - Create leave event\n"
      send_message(message, reply, true)
    end
  end

  def remove_message(message)
    settings.bot.api.delete_message(chat_id: message['chat']['id'], message_id: message['message_id'])
  end

  def send_message(message, reply, force_group)
    group_type = message['chat']['type']
    if (group_type == 'group' || group_type == 'supergroup') && !force_group
      settings.bot.api.send_message(chat_id: message['from']['id'], text: reply)
    else
      settings.bot.api.send_message(chat_id: message['chat']['id'], text: reply)
    end
  end

  def fetch_todays_event(message)
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
    send_message(message, reply, true)
  end

  def create_event(message, event)
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
          "title" => "#{event == "/remote" ? 'Remote' : 'Cuti'}",
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
        response = JSON.parse(response.body)
        reply = "#{response.code == 201 ? "Event berhasil dibuat dengan id #{response['event']['id']}" : 'Event gagal dibuat'}"
      rescue ArgumentError  
        reply = 'Format tanggal mulai atau selesai salah'
      end
    end
    remove_message(message)
    send_message(message, reply, false)
  end
end

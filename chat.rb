# Imports
require 'sinatra'
require 'haml'
require 'json'

class ChatWithFrames < Sinatra::Base
  
  # Server Configuration
  configure do
    set server: 'thin', connections: []
    enable :sessions
  end
  
  # Class variables definition and default assignment
  @@clientsByConnection ||= {}
  @@clientsByName ||= {}
  @@usernames ||= {}
  @@anonymous_counter ||= 0
  @@user_stream_clients ||= []
  @@private ||= {}

  
  # Setting up a thread that sends the user list to clients every second
  Thread.new do
    while true do
      sleep 1
      
      user_list = @@clientsByName.keys.sort
      
      @@user_stream_clients.each do |client| 
        client << "data: {#{%Q{"users"}}:#{user_list.to_json}, #{%Q{"num"}}:#{user_list.size} }\n\n" 
      end
      
    end
  end
  
  # Route definition
  get '/' do
    if session['error']
      error = session['error']
      session['error'] = nil
      haml :index, :locals => { :error_message => error }
    else
      haml :index
    end
  end
  
  get '/chat' do
    haml :chat
  end
  
  post '/register-to-chat' do
    username = params[:username]
    if (not @@clientsByName.has_key? username)
      session['user'] = username
      redirect '/chat'
    else
      session['error'] = 'Sorry, the username is already taken.'
      redirect '/'
    end
  end
  
  get '/chat-stream', provides: 'text/event-stream' do
    content_type 'text/event-stream'
    
    if (session['user'] == nil)
      redirect '/'
    else
      username = session['user'] #nombre del ultimo que llega
    end
    
    stream :keep_open do |out|
      add_connection(out, username)
      
      out.callback { remove_connection(out, username) }
      out.errback { remove_connection(out, username) }
    end
  end
  
  get '/chat-users', provides: 'text/event-stream' do
    stream :keep_open do |out|
      add_user_stream_client(out)
      
      out.callback { remove_user_stream_client out }
      out.errback { remove_user_stream_client out }
    end
  end

  post '/chat' do
    message = params[:message]
    puts message
    name = $1
    puts name
    sender = session['user']
    puts sender
    #Establecer el chat privado
    if message =~ /\s*\/(\w+):/
      puts "distingue el tipo de mensaje"
      name = $1
      puts name
      sender = session['user']
      puts sender
      if @@clientsByName.has_key? name
        if ((@@private[name] == nil) and (@@private[sender]==nil)) 
          @@private[name]=sender
          @@private[sender]=name
          puts "la establezco yo"
          stream_receiver = @@clientsByName[name]
          stream_sender = @@clientsByName[sender]
          stream_receiver << "data: Se ha establecido conversacion con #{sender}\n\n"
          stream_sender << "data: Se ha establecido conversacion con #{name}\n\n"
        else 
          stream_sender = @@clientsByName[sender]
          stream_sender << "data: Para establecer chat con #{name} cierre chats anteriores \n\n"
          puts "Error"
        end
        #puts "comprueba el usuario"
        #stream_receiver = @@clientsByName[name]
        #stream_sender = @@clientsByName[sender]
        #mensaje = []
        #mensaje = message.split(':'); 
        #for i in(1..mensaje.length()-1)
          #stream_receiver << "data: Modo privado #{sender}: #{mensaje[i]}\n\n"
          #stream_sender << "data: Modo privado #{sender}: #{mensaje[i]}\n\n"
        #end     
        
      else #User not found, then broadcast
        broadcast(message, session['user'])
      end
    elsif (message == "salir")
      puts "saliendo del canal"
      @@private[name]= nil
      @@private[sender]= nil
    elsif ((@@private[name] == sender) and (@@private[sender]== name))
      puts "mismo canal a y b se envian lo que quieran"
      puts name
      puts sender
      stream_receiver = @@clientsByName[name]
      stream_sender = @@clientsByName[sender]
      stream_receiver << "data: #{sender}: #{message}\n\n"
      stream_sender << "data: #{sender}: #{message}\n\n"
    else
      broadcast(message, session['user'])
    end
    "Message Sent" 
  end

  get '/*' do
    redirect '/'
  end
  
  private
  def add_connection(stream, username) 
    @@clientsByConnection[stream] = username
    @@clientsByName[username] = stream
    @@private[username] = nil
  end
  
  def add_user_stream_client(stream)
    @@user_stream_clients += [stream]
  end
  
  def remove_user_stream_client(stream)
    @@user_stream_clients.delete stream
  end
  
  def remove_connection(stream, username)
    @@clientsByConnection.delete stream
    @@clientsByName.delete username
    @@private.delete username
  end
  
  def broadcast(message, sender)
    @@clientsByConnection.each_key { |stream| stream << "data: #{sender}: #{message}\n\n" }
  end
  
  def pop_username_from_list(id)
    username = @@usernames[id]
    @@usernames.delete id
    return username
  end

  
end

ChatWithFrames.run!
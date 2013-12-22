require 'hipchat'
require 'dotenv'
require 'socket'
require 'nokogiri'
require 'systemu'

Dotenv.load

class VoiceListener
  def initialize
    @julius_thread = Thread.new do
      systemu "julius -C room.jconf -module"
    end
    sleep 2
    @socket = TCPSocket.open('localhost', 10500)
    @voice_input_enabled = true
    @hipchat = HipChat::Client.new(ENV['HIPCHAT_TOKEN'])
  end

  def listen
    puts 'listen start'
    data = ""
    while true
      data += @socket.recv(65535)
      next unless data_end?(data)

      command = parse_word(data)
      exec_command(command)
      data = ""
    end
  end

private

  def parse_word(data)
    recogout = data[%r/<RECOGOUT>.*<\/RECOGOUT>/m]
    return unless recogout

    xml = Nokogiri.parse(recogout)

    command = (xml/"RECOGOUT"/"SHYPO"/"WHYPO").map { |w|
      w["WORD"] && w["WORD"].size > 0 ? w["WORD"] : nil
    }.compact.first
  end

  def exec_command(command)
    return if command.to_s == ""

    if command == '[音声認識停止]'
      @voice_input_enabled = false
      `say -v alex 'voice input disable'`
      return
    elsif command == '[音声認識再開]'
      @voice_input_enabled = true
      `say -v alex 'voice input enabled'`
      return
    end

    return unless @voice_input_enabled
    puts "#{Time.now} #{command}"
    @hipchat[ENV['HIPCHAT_ROOM']].send('voice', command)
  end

  def data_end?(data)
    data[-2..-1] == ".\n"
  end
end


VoiceListener.new.listen
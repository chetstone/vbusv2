require 'socket'
require 'net/http'

class Vbus 

  Masterclear = 0x0500
  Answer = 0x0100
  Writerequest = 0x0200
  Readrequest = 0x0300
  #Writerequest = 0x0400
  Slaveclear = 0x0600
  Monitor = 0xffff

  # Some useful mnemonics for the RESOL BS plus controller.
  Syms = {:SMX => 0x01B0, :AHO => 0x0E00,:AHF => 0x0E01,
      :HND1 => 0x0026, :HND2 => 0x0027}
  

  def initialize(host='localhost', port=7053, dest=0x4221, debug=false)

    @debug = debug
    @dest = dest

    if (@debug && $PROGRAM_NAME == "dl2predict.rb")
      # don't actually talk to the vbus
    else
      @s = TCPSocket.open(host,port)
      line = @s.gets

      if (line.chop != "+HELLO")
        #puts "Not Hello, " + line.chop
        @s.close
        raise "Could not initialize vbus"
      else
        @s.puts("PASS vbus")
        @s.puts("DATA")
      end
      self.prepare
      #getmsg(Masterclear,2.0)
    end
  end

  def convertsym(param)
    id = Syms[param]
    id ||= param.hex
  end

  def checkv2sum(str, cmd)
    sum = 0
    ckbyte = str[-1]
    sstr = str[0 .. 13]
    sstr.each_byte { |c| sum +=c;
      #printf "0x%x\n",c
    }
    #puts "CKBYTE is " + ckbyte.to_s
    #printf "CMD is %x \n", (str[6]<<8) + str[5]
    isum = ~sum & 0x7f
    #puts "SUM is " + sum.to_s + " ISUM is " + isum.to_s
    if ( isum == ckbyte )
      if (cmd == Masterclear && ((str[6]<<8) + str[5]) == Masterclear)
        return true
      end
      sstr = fix_septett_for_read(sstr,7,6)

      if ( cmd == Answer  && ((str[6]<<8) + str[5]) == Answer)
        @answer = ((sstr[12]<<24)+ (sstr[11]<<16) +(sstr[10]<<8)+ sstr[9]).to_i 
        return true
      end
    else
      raise "Checksum bad: isum = 0x%x, ckbyte = 0x%x " % [isum, ckbyte]
    end
    if ( cmd == Monitor || isum != ckbyte)
      printf "Cmd: 0x%0.2x%0.2x, Dest: 0x%0.2x%0.2x, Src: 0x%0.2x%0.2x, ID: 0x%0.2x%0.2x, Val: %d, Sept: 0x%0.2x, Cksum: 0x%0.2x\n", sstr[6], sstr[5],
      sstr[1],sstr[0], sstr[3],sstr[2],sstr[8],sstr[7],(sstr[12]<<24)+ (sstr[11]<<16) +(sstr[10]<<8)+ sstr[9], sstr[13], ckbyte
      return isum == ckbyte
    end
    return false
  end

  def getmsg(cmd, timeout)
    timeout += Time.now.to_f
    puts "getmsg called" if @debug
    while ( (Time.now.to_f <  timeout) )
      if  IO.select([@s], nil, nil,0.2)
        char = @s.getc 
        if (char == 0xaa)
          puts "got AA at time #{timeout-Time.now.to_f}" if @debug
          str=@s.read(9)
          if (str[4] == 0x10) 
            puts "V1" if @debug
          elsif (str[4] == 0x20)
            puts "V2" if @debug
            str += @s.read(6)
            if checkv2sum(str, cmd)
              return true
            end
          end
        end
      end
    end
    raise "Timeout"
  end

  def fix_septett_for_read(str,offset,length)
    septett = 0
    i = 0
    septett = str[offset + length]
    #  if (septett != 0) then printf "Septett= 0x%0.2x ", septett
    #  end

    (0 .. length-1).each { |i| 
      if ((septett & (1 << i)) != 0)
        #printf "Set bit %d ", i
        str [offset + i] |= 0x80;
      end
    }
    return str
  end

  def gen_septett(str)
    offset = 8 # fixed offset and length for V2
    length = 6
    septett = 0
    i = 0

    (0 .. length-1).each { |i| 
      if ((str[offset + i] & 0x80) == 0x80)
        str[offset + i] &= 0x7f
        septett |= (1 << i)
      end
    }
    str.push(septett)
  end

  def gen_cksum(msg)
    # include everything so far gen'd but the sync byte
    str = msg[1 .. -1]
    crc = 0x7f
    
    str.each { |v| crc = (crc - v) & 0x7f }
    msg.push crc
  end

  def push_multiple(msg, val, len)
    (0 .. len-1).each {|l|
      msg.push((val>>(8*l) & 0xff))
    }
  end

  def create_datagram(cmd,id,val)
    msg = Array.new
    
    msg.push 0xaa #sync byte
    push_multiple(msg,@dest,2) # dest 
    push_multiple(msg, 0x0020,2) # src 
    msg.push 0x20 # V2 protocol
    push_multiple(msg, cmd, 2)
    push_multiple(msg, id, 2)
    push_multiple(msg, val, 4)
    gen_septett(msg)
    gen_cksum(msg)

  end

  def sendmsg(msg)
    msg.each { |v| @s.putc v }
  end


  def putmsg(cmd, id, val = 0)
    msg = create_datagram(cmd,id,val)
    sstr = msg[1 .. 15]
    if (@debug) then printf "Cmd: 0x%0.2x%0.2x, Dest: 0x%0.2x%0.2x, Src: 0x%0.2x%0.2x, ID: 0x%0.2x%0.2x, Val: %d, Sept: 0x%0.2x, Cksum: 0x%0.2x\n", sstr[6], sstr[5],
      sstr[1],sstr[0], sstr[3],sstr[2],sstr[8],sstr[7],(sstr[12]<<24)+ (sstr[11]<<16) +(sstr[10]<<8)+ sstr[9], sstr[13], sstr[14]
    end
    sendmsg(msg)
    true
  end

  def writeval(readwrite, param, val)
    id = convertsym(param)
    i = 0
    msg = ""
    begin
        i += 1
        putmsg(readwrite, id, val.to_i)
        getmsg(Answer,0.8)
        @answer
    rescue  => e
      msg += e
      retry if i < 4
      raise msg
    end
    @answer
  end

  # Get ready to read or write data
  def prepare
    i = 0
    msg = ""
    begin
      i += 1
      getmsg(Masterclear,2.0)
    rescue  => e
      msg += e
      retry if i < 4
      raise msg
    end
  end

  def release
    putmsg(Slaveclear,0)
  end
    
  def close
    @s.close
  end

  # write multiple values to the dl2
  def send(h)
    msg = ""
    h.each { |k,v|
      if (@debug && $PROGRAM_NAME == "dl2predict.rb")
       msg += "Would write %s, %d to vbus. " % [k, v]
      else
       msg += "New value of :#{k.to_s}:  " + self.writeval(Vbus::Writerequest,k, v).to_s + ". "
      end
      
    }
    msg
  end
  
end

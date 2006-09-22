{
  Translation of the A52 headers for FreePascal
  Copyright (C) 2006 by Ivo Steinmann
}

(*
 * a52.h
 * Copyright (C) 2000-2002 Michel Lespinasse <walken@zoy.org>
 * Copyright (C) 1999-2000 Aaron Holtzman <aholtzma@ess.engr.uvic.ca>
 *
 * This file is part of a52dec, a free ATSC A-52 stream decoder.
 * See http://liba52.sourceforge.net/ for updates.
 *
 * a52dec is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * a52dec is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *)


{
Using the liba52 API
--------------------

liba52 provides a low-level interface to decoding audio frames encoded
using ATSC standard A/52 aka AC-3. liba52 provides downmixing and
dynamic range compression for the following output configurations:

A52_CHANNEL  : Dual mono. Two independant mono channels.
A52_CHANNEL1 : First of the two mono channels above.
A52_CHANNEL2 : Second of the two mono channels above.
A52_MONO     : Mono.
A52_STEREO   : Stereo.
A52_DOLBY    : Dolby surround compatible stereo.
A52_3F       : 3 front channels (left, center, right)
A52_2F1R     : 2 front, 1 rear surround channel (L, R, S)
A52_3F1R     : 3 front, 1 rear surround channel (L, C, R, S)
A52_2F2R     : 2 front, 2 rear surround channels (L, R, LS, RS)
A52_3F2R     : 3 front, 2 rear surround channels (L, C, R, LS, RS)

A52_LFE      : Low frequency effects channel. Normally used to connect a
               subwoofer. Can be combined with any of the above channels.
               For example: A52_3F2R | A52_LFE -> 3 front, 2 rear, 1 LFE (5.1)


Initialization
--------------

sample_t * a52_init (uint32_t mm_accel);

Initializes the A/52 library. Takes as a parameter the acceptable
optimizations which may be used, such as MMX. These are found in the
included header file 'mm_accel', along with an autodetection function
(mm_accel()). Currently, the only accelleration implemented is
MM_ACCEL_MLIB, which uses the 'mlib' library if installed. mlib is
only available on some Sun Microsystems platforms.

The return value is a pointer to a properly-aligned sample buffer used
for output samples.


Probing the bitstream
---------------------

int a52_syncinfo (uint8_t * buf, int * flags,
                  int * sample_rate, int * bit_rate);

The A/52 bitstream is composed of several a52 frames concatenated one
after each other. An a52 frame is the smallest independantly decodable
unit in the stream.

buf must contain at least 7 bytes from the input stream. If these look
like the start of a valid a52 frame, a52_syncinfo() returns the size
of the coded frame in bytes, and fills flags, sample_rate and bit_rate
with the information encoded in the stream. The returned size is
guaranteed to be an even number between 128 and 3840. sample_rate will
be the sampling frequency in Hz, bit_rate is for the compressed stream
and is in bits per second, and flags is a description of the coded
channels: the A52_LFE bit is set if there is an LFE channel coded in
this stream, and by masking flags with A52_CHANNEL_MASK you will get a
value that describes the full-bandwidth channels, as one of the
A52_CHANNEL...A52_3F2R flags.

If this can not possibly be a valid frame, then the function returns
0. You should then try to re-synchronize with the a52 stream - one way
to try this would be to advance buf by one byte until its contents
looks like a valid frame, but there might be better
application-specific ways to synchronize.

It is recommended to call this function for each frame, for several
reasons: this function detects errors that the other functions will
not double-check, consecutive frames might have different lengths, and
it helps you re-sync with the stream if you get de-synchronized.


Starting to decode a frame
--------------------------

int a52_frame (a52_state_t * state, uint8_t * buf, int * flags,
           sample_t * level, sample_t bias);

This starts the work of decoding the A/52 frame (to be completed using
a52_block()). buf should point to the beginning of the complete frame
of the full size returned by a52_syncinfo().

You should pass in the flags the speaker configuration that you
support, and liba52 will return the speaker configuration it will use
for its output, based on what is coded in the stream and what you
asked for. For example, if the stream contains 2+2 channels
(a52_syncinfo() returned A52_2F2R in the flags), and you have 3+1
speakers (you passed A52_3F1R), then liba52 will choose do downmix to
2+1 speakers, since there is no center channel to send to your center
speaker. So in that case the left and right channels will be
essentially unmodified by the downmix, and the two surround channels
will be added together and sent to your surround speaker. liba52 will
return A52_2F1R to indicate this.

The good news is that when you downmix to stereo you dont have to
worry about this, you will ALWAYS get a stereo output no matter what
was coded in the stream. For more complex output configurations you
will have to handle the case where liba52 couldnt give you what you
wanted because some of the channels were not encoded in the stream
though.

Level, bias, and A52_ADJUST_LEVEL:

Before downmixing, samples are floating point values with a range of
[-1,1]. Most types of downmixing will combine channels together, which
will potentially result in a larger range for the output
samples. liba52 provides two methods of controlling the range of the
output, either before or after the downmix stage.

If you do not set A52_ADJUST_LEVEL, liba52 will multiply the samples
by your level value, so that they fit in the [-level,level]
range. Then it will apply the standardized downmix equations,
potentially making the samples go out of that interval again. The
level parameter is not modified.

Setting the A52_ADJUST_LEVEL flag will instruct liba52 to treat your
level value as the intended range interval after downmixing. It will
then figure out what level to use before the downmix (what you should
have passed if you hadnt used the A52_ADJUST_LEVEL flag), and
overwrite the level value you gave it with that new level value.

The bias represents a value which should be added to the result
regardless:

output_sample = (input_sample * level) + bias;

For example, a bias of 384 and a level of 1 tells liba52 you want
samples between 383 and 385 instead of -1 and 1. This is what the
sample program a52dec does, as it makes it faster to convert the
samples to integer format, using a trick based on the IEEE
floating-point format.

This function also initialises the state for that frame, which will be
reused next when decoding blocks.


Dynamic range compression
-------------------------

void a52_dynrng (a52_state_t * state,
                 sample_t (* call) (sample_t, void *), void * data);

This function is purely optional. If you dont call it, liba52 will
provide the default behaviour, which is to apply the full dynamic
range compression as specified in the A/52 stream. This basically
makes the loud sounds softer, and the soft sounds louder, so you can
more easily listen to the stream in a noisy environment without
disturbing anyone.

If you do call this function and set a NULL callback, this will
totally disable the dynamic range compression and provide a playback
more adapted to a movie theater or a listening room.

If you call this function and specify a callback function, this
callback might be called up to once for each block, with two
arguments: the compression factor 'c' recommended by the bitstream,
and the private data pointer you specified in a52_dynrng(). The
callback will then return the amount of compression to actually use -
typically pow(c,x) where x is somewhere between 0 and 1. More
elaborate compression functions might want to use a different value
for 'x' depending wether c>1 or c<1 - or even something more complex
if this is what you want.


Decoding blocks
---------------

int a52_block (a52_state_t * state, sample_t * samples);

Every A/52 frame is composed of 6 blocks, each with an output of 256
samples for each channel. The a52_block() function decodes the next
block in the frame, and should be called 6 times to decode all of the
audio in the frame. After each call, you should extract the audio data
from the sample buffer.

The sample pointer given should be the one a52_init() returned.

After this function returns, the samples buuffer will contain 256
samples for the first channel, followed by 256 samples for the second
channel, etc... the channel order is LFE, left, center, right, left
surround, right surround. If one of the channels is not present in the
liba52 output, as indicated by the flags returned by a52_frame(), then
this channel is skipped and the following channels are shifted so
liba52 does not leave an empty space between channels.


Pseudocode example
------------------

sample_t * samples = a52_init (mm_accel());

loop on input bytes:
  if at least 7 bytes in the buffer:

    bytes_to_get = a52_syncinfo (...)

    if bytes_to_get == 0:
      goto loop to keep looking for sync point
    else
      get rest of bytes

      a52_frame (state, buf, ...)
      [a52_dynrng (state, ...); this is only optional]
      for i = 1 ... 6:
        a52_block (state, samples)
        convert samples to integer and queue to soundcard
}

unit a52;

{$mode objfpc}
{$MINENUMSIZE 4}

interface

uses
  ctypes;

{$UNDEF LIBA52_DOUBLE}

{$IFDEF WINDOWS}
  {$DEFINE DYNLINK}
{$ENDIF}

{$IFDEF DYNLINK}
const
{$IF Defined(WINDOWS)}
  a52lib = 'a52.dll';
{$ELSEIF Defined(UNIX)}
  a52lib = 'liba52.so';
{$ELSE}
  {$MESSAGE ERROR 'DYNLINK not supported'}
{$IFEND}
{$ELSE}
  {$LINKLIB a52}
{$ENDIF}

type
  psample_t = ^sample_t;
{$IFNDEF LIBA52_DOUBLE}
  sample_t = cfloat;
{$ELSE}
  sample_t = cdouble;
{$ENDIF}


// include a52_internal.h

type
  pba_t = ^ba_t;
  ba_t = record
    bai         : cuint8;                   (* fine SNR offset, fast gain *)
    deltbae     : cuint8;                   (* delta bit allocation exists *)
    deltba      : array[0..49] of cuint8;   (* per-band delta bit allocation *)
  end;

  pexpbap_t = ^expbap_t;
  expbap_t = record
    exp         : array[0..255] of cuint8;  (* decoded channel exponents *)
    bap         : array[0..255] of cint8;   (* derived channel bit allocation *)
  end;

  pa52_state_s = ^a52_state_s;
  a52_state_s = record
    fscod       : cuint8;      (* sample rate *)
    halfrate    : cuint8;      (* halfrate factor *)
    acmod       : cuint8;      (* coded channels *)
    lfeon       : cuint8;      (* coded lfe channel *)
    clev        : sample_t;      (* centre channel mix level *)
    slev        : sample_t;      (* surround channels mix level *)

    output      : cint;         (* type of output *)
    level       : sample_t;     (* output level *)
    bias        : sample_t;      (* output bias *)

    dynrnge     : cint;        (* apply dynamic range *)
    dynrng      : sample_t;        (* dynamic range *)
    dynrngdata  : pointer;      (* dynamic range callback funtion and data *)
    dynrngcall  : function(range: sample_t; dynrngdata: pointer): sample_t; cdecl;

    chincpl     : cuint8;        (* channel coupled *)
    phsflginu   : cuint8;      (* phase flags in use (stereo only) *)
    cplstrtmant : cuint8;    (* coupling channel start mantissa *)
    cplendmant  : cuint8;     (* coupling channel end mantissa *)
    cplbndstrc  : cuint32;    (* coupling band structure *)
    cplco       : array[0..4] of array[0..17] of sample_t;  (* coupling coordinates *)

    (* derived information *)
    cplstrtbnd  : cuint8;     (* coupling start band (for bit allocation) *)
    ncplbnd     : cuint8;        (* number of coupling bands *)

    rematflg    : cuint8;       (* stereo rematrixing *)

    endmant     : array[0..4] of cuint8;     (* channel end mantissa *)

    bai         : cuint16;       (* bit allocation information *)

    buffer_start: pcuint32;
    lfsr_state  : cuint16;    (* dither state *)
    bits_left   : cuint32;
    current_word: cuint32;

    csnroffst   : cuint8;      (* coarse SNR offset *)
    cplba       : ba_t;         (* coupling bit allocation parameters *)
    ba          : array[0..4] of ba_t;         (* channel bit allocation parameters *)
    lfeba       : ba_t;         (* lfe bit allocation parameters *)

    cplfleak    : cuint8;       (* coupling fast leak init *)
    cplsleak    : cuint8;       (* coupling slow leak init *)

    cpl_expbap  : expbap_t;
    fbw_expbap  : array[0..4] of expbap_t;
    lfe_expbap  : expbap_t;

    samples     : psample_t;
    downmixed   : cint;
  end;


// include mm_accel.h

const
(* generic accelerations *)
  MM_ACCEL_DJBFFT     = $00000001;

(* x86 accelerations *)
  MM_ACCEL_X86_MMX    = $80000000;
  MM_ACCEL_X86_3DNOW  = $40000000;
  MM_ACCEL_X86_MMXEXT = $20000000;

//function mm_accel: cuint32; cdecl; external {$IFDEF DYNLINK}a52lib{$ENDIF};


// include a52.h

type
  pa52_state_t = ^a52_state_t;
  a52_state_t = a52_state_s;

  dynrng_call = function(s: sample_t; data: pointer): sample_t; cdecl;

const
   A52_CHANNEL      = 0;
   A52_MONO         = 1;
   A52_STEREO       = 2;
   A52_3F           = 3;
   A52_2F1R         = 4;
   A52_3F1R         = 5;
   A52_2F2R         = 6;
   A52_3F2R         = 7;
   A52_CHANNEL1     = 8;
   A52_CHANNEL2     = 9;
   A52_DOLBY        = 10;
   A52_CHANNEL_MASK = 15;

   A52_LFE          = 16;
   A52_ADJUST_LEVEL = 32;


function a52_init(mm_accel: cuint32): pa52_state_t; cdecl; external {$IFDEF DYNLINK}a52lib{$ENDIF};
function a52_samples(state: pa52_state_t): psample_t; cdecl; external {$IFDEF DYNLINK}a52lib{$ENDIF};
function a52_syncinfo(buf: pcuint8; var flags: cint; var sample_rate: cint; var bit_rate: cint): cint; cdecl; external {$IFDEF DYNLINK}a52lib{$ENDIF};
function a52_frame(state: pa52_state_t; buf: pcuint8; var flags: cint; var level: sample_t; bias: sample_t): cint; cdecl; external {$IFDEF DYNLINK}a52lib{$ENDIF};
procedure a52_dynrng(state: pa52_state_t; call: dynrng_call; data: pointer); cdecl; external {$IFDEF DYNLINK}a52lib{$ENDIF};
function a52_block(state: pa52_state_t): cint; cdecl; external {$IFDEF DYNLINK}a52lib{$ENDIF};
procedure a52_free(state: pa52_state_t); cdecl; external {$IFDEF DYNLINK}a52lib{$ENDIF};



{
  Developer of the A52 helpers for FreePascal
  Copyright (C) 2006 by Ivo Steinmann
}

type
  read_func  = function(ptr: pointer; size, nmemb: culong; datasource: pointer): culong; cdecl;
  seek_func  = function(datasource: pointer; offset: cint64; whence: cint): cint; cdecl;
  close_func = function(datasource: pointer): cint; cdecl;
  tell_func  = function(datasource: pointer): clong; cdecl;

  pa52_decoder = ^a52_decoder;
  a52_decoder = record
  // buffer
    inbuf       : array[0..4095] of cuint8;
    inbuf_ptr   : pcuint8;
    frame_size  : cint;
    flags       : cint;
    channels    : cint;
    state       : pa52_state_t;
    samples     : psample_t;

  // callbacks
    datasource  : pointer;
    read        : read_func;
    seek        : seek_func;
    close       : close_func;
    tell        : tell_func;

  // codec info
    sample_rate : cint;
    bit_rate    : cint;
    //req_chan    : cint;
  end;

function a52_decoder_init(mm_accel: cuint32; datasource: pointer; read: read_func; seek: seek_func; close: close_func; tell: tell_func): pa52_decoder;
function a52_decoder_read(decoder: pa52_decoder; buffer: pointer; length: cint): cint;
procedure a52_decoder_free(decoder: pa52_decoder);

implementation

function a52_decoder_init(mm_accel: cuint32; datasource: pointer; read: read_func; seek: seek_func; close: close_func; tell: tell_func): pa52_decoder;
begin
  GetMem(Result, Sizeof(a52_decoder));
  FillChar(Result^, Sizeof(a52_decoder), 0);
  Result^.state := a52_init(mm_accel);
  Result^.samples := a52_samples(Result^.state);
  Result^.inbuf_ptr := @Result^.inbuf;
  Result^.datasource := datasource;
  Result^.read := read;
  Result^.seek := seek;
  Result^.close := close;
  Result^.tell := tell;
end;

procedure a52_decoder_free(decoder: pa52_decoder);
begin
  if not Assigned(decoder) then
    Exit;

  a52_free(decoder^.state);
  FreeMem(decoder);
end;

procedure float_to_int(f: psample_t; s16: pcint16; nchannels: cint);
var
  i, c: cint;
begin
  nchannels := nchannels * 256;
  for i := 0 to 255 do
  begin
    c := 0;
    while c < nchannels do
    begin
      s16^ := Round(f[i + c]);
      c := c + 256;
      Inc(s16);
    end;
  end;
end;

function a52_decoder_read(decoder: pa52_decoder; buffer: pointer; length: cint): cint;
const
  HEADER_SIZE = 7;
  ac3_channels: array[0..7] of cint = (2,1,2,3,3,4,4,5);
var
  num, ofs: cint;
  flags, i, len: cint;
  sample_rate, bit_rate: cint;
  level: cfloat;
begin
  ofs := 0;
  num := length;
  while num > 0 do
  begin
    len := PtrInt(decoder^.inbuf_ptr) - PtrInt(@decoder^.inbuf);
    if decoder^.frame_size = 0 then
    begin
      (* no header seen : find one. We need at least 7 bytes to parse it *)
      len := HEADER_SIZE - len;
      {if len > buf_size then
        len := buf_size;}

      if decoder^.read(decoder^.inbuf_ptr, 1, len, decoder^.datasource) <> len then
        Exit(ofs);
      Inc(decoder^.inbuf_ptr, len);

      if PtrInt(decoder^.inbuf_ptr) - PtrInt(@decoder^.inbuf) = HEADER_SIZE then
      begin
        len := a52_syncinfo(@decoder^.inbuf, decoder^.flags, sample_rate, bit_rate);
        if len = 0 then
        begin
          (* no sync found : move by one byte (inefficient, but simple!) *)
          Move(decoder^.inbuf[1], decoder^.inbuf[0], HEADER_SIZE - 1);
          Dec(decoder^.inbuf_ptr);
        end else begin
          decoder^.frame_size := len;
          (* update codec info *)
          decoder^.sample_rate := sample_rate;
          decoder^.bit_rate := bit_rate;
          decoder^.channels := ac3_channels[decoder^.flags and $7];
          if decoder^.flags and A52_LFE <> 0 then
            Inc(decoder^.channels);

          // test against user channel settings (wrong here)
          {if decoder^.req_chan = 0 then
            decoder^.req_chan := decoder^.channels else
            if decoder^.channels < decoder^.req_chan then
              decoder^.req_chan := decoder^.channels;}
        end;
      end;
    end else
      if len < decoder^.frame_size then
      begin
        len := decoder^.frame_size - len;
        {if len > buf_size then
          len := buf_size;}

        if decoder^.read(decoder^.inbuf_ptr, 1, len, decoder^.datasource) <> len then
          Exit(ofs);
        Inc(decoder^.inbuf_ptr, len);
      end else begin
        flags := A52_STEREO;//decoder^.flags;
        level := 1;

        if a52_frame(decoder^.state, @decoder^.inbuf, flags, level, 384) <> 0 then
        begin
          decoder^.inbuf_ptr := @decoder^.inbuf;
          decoder^.frame_size := 0;
          Continue;
        end;

        for i := 0 to 5 do
        begin
          if a52_block(decoder^.state) <> 0 then
            Exit(-1);

          float_to_int(decoder^.samples, pointer(PtrUInt(buffer) + Ofs + 2{channels}*i*256*2{sample_size}), 2{channels});
        end;

        decoder^.inbuf_ptr := @decoder^.inbuf;
        decoder^.frame_size := 0;

        ofs := ofs + 2{channels}*(6*256){samples}*2{sample_size};
        num := num - 2{channels}*(6*256){samples}*2{sample_size};
      end;
  end;

  Result := ofs;
end;

end.
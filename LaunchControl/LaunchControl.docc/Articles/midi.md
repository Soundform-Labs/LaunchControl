# Understanding MIDI Protocol

A standard protocol for communication between electronic musical instruments and devices.

<!--
1. Add diagrams illustrating MIDI device connections and message structure.
2. Include code examples showing how to send, receive, and parse MIDI messages.
3. Explain common MIDI message types (Note On/Off, Control Change, etc.) with examples.
4. Show practical use cases like controlling UI elements or handling velocity.
5. Organize content with clear sections: Overview, Message Structure, Common Messages, Practice, and Code Examples.
-->

## Overview

MIDI (Musical Instrument Digital Interface) is a technical standard that enables communication between
electronic musical instruments, computers, and other related devices. It allows these devices to send and
receive messages that control musical performance, such as note information, control changes, and timing
signals. Since its introduction in the early 1980s, MIDI has become a foundational protocol in music
production, live performance, and digital audio workflows.

MIDI does not transmit audio itself but rather data that represents musical events and controls, making it
highly efficient for real-time performance and flexible control across various devices and software.

![Bidirectional MIDI communication between device and host](midi-connectivity.png)
*Figure 1: Bidirectional MIDI communication between device and host.*

MIDI devices, such as keyboards or controllers, communicate with host computers or synthesizers by sending
MIDI messages that represent musical events or control changes. This communication is bidirectional: the
device sends messages to the host to trigger notes or control parameters, while the host can send messages
back to the device to update its state—for example, lighting up LEDs on a controller or providing other forms
of feedback. The diagram below illustrates this typical connection flow, showing how data moves between the
MIDI device and the host in both directions.

### MIDI Message Structure

MIDI messages are the building blocks of communication between devices. Each message consists of one
status byte followed by one or two data bytes. The status byte indicates the type of message and the MIDI
channel it belongs to, while the data bytes provide details such as note number or velocity.

#### Message Format

| Byte Type | Description | Example Value |
| :-------: | :---------: | :-----------: |
| Status Byte | Identifies message type and channel | 0x90 (Note On, Ch. 1) |
| Data Byte 1 | Usually note number or controller ID | 0x3C (Middle C note) |
| Data Byte 2 | Usually velocity or controller value | 0x40 (velocity 64)

Each MIDI channel ranges from 1 to 16, and the status byte encodes this in its lower nibble (half byte).

![Message Structure](midi-message-structure.png)
*Figure 2: MIDI message byte format showing status and data bytes.*

#### Common MIDI Messages

MIDI communication relies on several fundamental message types that enable devices to exchange musical
instructions. The Note On message tells a device to begin playing a note and includes the note’s pitch
(for example, middle C, 0x3C) and velocity, which reflects how forcefully the note is played. Its counterpart,
the Note Off message, signals the device to stop playing that note, typically with a velocity of zero. The
status byte for Note On on channel 1 is 0x90, and for Note Off, it’s 0x80.

Control Change (CC) messages modify parameters like volume, pan, or modulation. Each message carries a
controller number identifying the parameter and a value setting its level—controller 7 (0x07) commonly adjusts
volume. The status byte for Control Change on channel 1 is 0xB0.

The Program Change message switches the instrument or sound patch on the device. It contains a single data
byte representing the program number to select the desired sound. The status byte for Program Change on 
channel 1 is 0xC0.

Finally, Pitch Bend messages enable smooth, continuous pitch variations by sending a 14-bit value split over
two data bytes (least and most significant). The status byte for Pitch Bend on channel 1 is 0xE0. This allows
expressive effects such as vibrato and pitch slides.

Together, these core messages form the basis of MIDI’s ability to communicate detailed musical commands
between instruments, controllers, and software.

### Section header

<!--@START_MENU_TOKEN@-->Text<!--@END_MENU_TOKEN@-->

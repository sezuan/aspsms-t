# http://www.swissjabber.ch/
# https://github.com/micressor/aspsms-t
#
# Copyright (C) 2006-2012 Marco Balmer <marco@balmer.name>
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU Library General Public License as published
# by the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Library General Public License for more details.
#
# You should have received a copy of the GNU Library General Public
# License along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301,
# USA.

=head1 NAME

aspsms-t - jabber presence handler

=head1 METHODS

=cut

package ASPSMS::Presence;

use strict;
use ASPSMS::config;
use vars qw(@EXPORT @ISA);
use Exporter;

@ISA 			= qw(Exporter);
@EXPORT 		= qw(sendError sendPresence InPresence sendGWNumPresences);


use Sys::Syslog;
use ASPSMS::aspsmstlog;
use ASPSMS::Jid;
use ASPSMS::Message;
use ASPSMS::Storage;


sub sendError {
my ($msg, $to, $from, $code, $text) = @_;

=head2 sendError()

If something goes wrong, this function send a jabber error iq message to
the jabber user.

=cut
	
$msg->SetType('error');
$msg->SetFrom($from);
$msg->SetTo($to);
$msg->SetErrorCode($code);
$msg->SetError($text);
$ASPSMS::config::Connection->Send($msg);

aspsmst_log('warning',"sendError($to): $code,$text");
#sendAdminMessage("info","sendError(): Message to \"$to $code,$text\"");	

}


sub InPresence {

=head2 InPresence()

Incoming presence. Reply to subscription requests with proper subscription 
actions, reply to probe presence with gateways presence.
On registration requests, accept and send a gateways status presence update.

=cut

$ASPSMS::config::aspsmst_stat_stanzas++;

my $sid 		= shift;
my $presence 		= shift;
my $from 		= $presence->GetFrom();
my $to 			= $presence->GetTo();
my ($number) 		= split(/@/, $to);
my $type 		= $presence->GetType();
my $iq_show 		= $presence->GetShow();
my $status 		= $presence->GetStatus();
my $xml			= $presence->GetXML();
my $barejid 		= get_barejid($from);

aspsmst_log('debug',"InPresence($barejid): Got type=$type to=$to number=$number");

my $user = get_record("jid",$barejid);

if ($type eq "error") {
  # We do nothing in this case (loops)
  aspsmst_log('debug',"InPresence($barejid): xml=$xml");
  return; }

  # If we get no record we will send a unsubscribed
  if ($user == -2) {
    aspsmst_log("warning","InPresence($from): Has no $ASPSMS::config::ident account registered -- Send type `unsubscribed'");
    sendPresence($from, $to, 'unsubscribed');
    return 0;

  } ### if ($user == -2)

if ($type eq 'subscribe') {

  if (($number !~ /^\+[0-9]{3,50}$/) and ($to =~ /\@/)) {
    aspsmst_log('err',"InPresence(): Error: Invalid number `$number' got.");
    sendPresence($from, $to, 'unsubscribed');
    return;
   } ### (($number !~
  
  sendPresence($from, $to, 'subscribed');
  sendPresence($from, $to, undef);

  if (($number =~ /^\+[0-9]{3,50}$/) and ($to =~ /\@/)) {
    sendGWNumPresences($number, $from);
  } else {
    sendPresence($from, $to, 'subscribed');
  }

 } ### ($type eq 'subscribe')

elsif (($type eq '') or ($type eq 'probe')) {

  if ( $number =~ /^\+[0-9]{3,50}$/ ) {
    sendGWNumPresences($number, $from); }
  
  if ($to eq "$ASPSMS::config::service_name") {
    aspsmst_log('notice',"InPresence($barejid): Send presence status: \"Transport uptime: $ASPSMS::config::transport_uptime_hours in hour(s) SMS/Hour: $ASPSMS::config::aspsmst_stat_msg_per_hour\"");
    sendPresence($from,$to,undef,$iq_show,"Transport uptime: $ASPSMS::config::transport_uptime_hours SMS/h: $ASPSMS::config::aspsmst_stat_msg_per_hour $ASPSMS::config::release");
  }
} 
elsif ($type eq 'unsubscribe') {
 if ($to eq "$ASPSMS::config::service_name") {
    ASPSMS::Iq::jabber_iq_remove($from,undef,
	"$ASPSMS::config::passwords/$barejid");
 }
    sendPresence($from, $to, 'unsubscribed');
 }
elsif ($type eq 'unavailable') {
  aspsmst_log('debug',"InPresence($barejid): Send 'unavailable`");
  sendPresence($from, $to, 'unavailable');
 }

} ### END of InPresence ###


sub sendGWNumPresences 
{
 my ($number, $to) = @_;	

 if ($number !~ /^\+[0-9]{3,50}$/) {
   aspsmst_log('debug',"sendGWNumPresences($to): This '$number` is no number -- skipped");
   return 1;
 }


 my $prefix = substr($number, 0, 5);
 my $presence = new Net::Jabber::Presence();

=head2 sendGWNumPresences()

If you have added sms numbers as a jabber roster contact. This function will
set the status of this contacts to online if everything is ok with aspsms-t.

Additionally it add costs for an sms to this contact in the status line
of this jabber roster user.

=cut

 #
 # How much costs this number prefix.
 #
 
 my ($credits);
 
 for (my $i=3;$i<=14;$i++)
  {

=head2

=over 4

=item * Check prefix between 3 and 14 numbers

=item * If a prefix was found it add corresponding costs in credits to
the status line of this contact.

=back

=cut

   $prefix 	= substr($number, 0, $i);
   $prefix =~ s/\+/00/g;
   $credits 	= $ASPSMS::config::prefix_data->{"$prefix"};
   aspsmst_log('debug',"sendGWNumPresences($to): Try $prefix credits=$credits");
   unless($credits eq "")
    { 
     #
     # Prefix found, exit for
     #
     aspsmst_log('debug',"sendGWNumPresences($to): Prefix $prefix found credits=$credits exit for");
     last; 
    } ### END of unles($credits
  } ### END of for (my$
  
 if($credits eq "")
  { 
   $credits = "1"; 
   aspsmst_log('debug',"sendGWNumPresences($to): No matching prefix found, set credits=$credits");
  }
  
 sendPresence($to,"$number\@$ASPSMS::config::service_name",undef,undef,"Credits: $credits",5);

 aspsmst_log('debug',"sendGWNumPresences($to): Sending presence for $number prefix=$prefix credits=$credits");

} ### END of sendGWNumPresences ###


sub sendPresence {
my ($to, $from, $type, $show, $status) = @_;

=head2 sendPresence()

This fucntion sends all presence stanzas which going out from aspsms-t.

We have to use ¨type '` instead of 'available', because this does not work
with all jabber servers.

=cut

my $pres = new Net::Jabber::Presence();

$pres->SetType($type);

unless($show eq "") {
  $pres->SetShow($show); }

unless($status eq "") {
  $pres->SetStatus($status); }

$pres->SetTo($to);
$pres->SetFrom($from);

my $to_barejid = get_barejid($to);
aspsmst_log('debug',"sendPresence($to_barejid): Sending presence type `$type', show `$show' and status `$status'");

$ASPSMS::config::Connection->Send($pres);

}

1;

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006-2012 Marco Balmer <marco@balmer.name>

The Debian packaging is licensed under the 
GPL, see `/usr/share/common-licenses/GPL-2'.

=cut

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

aspsms-t - connection module

=head1 DESCRIPTION

This module is an interface between the jabber world and the sms/aspsms.com
related world.

=head1 METHODS

=cut

package ASPSMS::Connection;

use strict;
use vars qw(@EXPORT @ISA);
use Exporter;

@ISA                    = qw(Exporter);
@EXPORT                 = qw(exec_SendTextSMS);

use ASPSMS::config;
use IO::Socket;
use ASPSMS::aspsmstlog;
use ASPSMS::xmlmodel;
use ASPSMS::ShowBalance;
use ASPSMS::ConnectionASPSMS;
use ASPSMS::Regex;
use ASPSMS::UCS2;
use Sys::Syslog;

openlog($ASPSMS::config::ident,'','user');

sub exec_SendTextSMS 
 {
	my $number              	= shift;
	my $numbernotification 		= $number;
	my $mess                	= shift;
	my $login               	= shift;
	my $password            	= shift;
	my $phone               	= shift;
	my $signature           	= shift;
	my $jid				= shift;
	my $aspsmst_transaction_id 	= shift; 
	my $msg_id			= shift;
	my $msg_type			= shift;

=head2 exec_SendTextSMS()

my ($errorcode,$errormessage) = exec_SendTextSMS(11 vars);

We read all login information, sms message, passwords and more to
generate an xml request.

=cut
        aspsmst_log('debug',"id:$aspsmst_transaction_id ".
	"exec_SendTextSMS(): Begin");

	# Generate SMS Request
	my $aspsmsrequest;
	my $flag_ucs2_mess = check_for_ucs2($mess);
        aspsmst_log('debug',"id:$aspsmst_transaction_id exec_SendTextSMS(): " .
	"check_for_ucs2(): $flag_ucs2_mess");

=head2

=over 4

=item * flag_ucs2_mess (1=true), we convert the message to an binary ucs2
message. ucs2 messages are only supported up to 83 characters.

=cut

        if($flag_ucs2_mess == 1)
	 {
	  $mess 	 = convert_to_ucs2($mess);
	  #
	  # Check length of message.
	  #
	  my $mess_length = length($mess);
	  if($mess_length > 160)
	   {
		
		return (	501,
				"Arabic & other oriental characters are only up to 83 characteres supported",
				undef,
				undef,
				$aspsmst_transaction_id);
	   } ### END of if($mess_length > 160)
	  $aspsmsrequest = xmlSendBinarySMS(	$login,
						$password,
						$phone,
						$number,
						$mess,
						$aspsmst_transaction_id ,
						$jid,
						$numbernotification,
						$ASPSMS::config::affiliateid,
						$msg_id,
						$msg_type);

 	 } ### if($flag_ucs2_mess == 1)
	else
	 {

=back

=over 4

=item * If flag_ucs2_mess is 0, we send the message normal as text message

=back

=cut

	  ($mess,$number,$signature) 	= regexes($mess,$number,$signature);
	  $aspsmsrequest = xmlSendTextSMS(	$login,
						$password,
						$phone,
						$number,
						$mess,
						$aspsmst_transaction_id ,
						$jid,
						$numbernotification,
						$ASPSMS::config::affiliateid,
						$msg_id,
						$msg_type);

	 } ### if($flag_ucs2_mess == 1)

	my $completerequest     = xmlGenerateRequest($aspsmsrequest);
	my @ret_CompleteRequest 
	= exec_ConnectionASPSMS($completerequest,
				$aspsmst_transaction_id);

	if($ret_CompleteRequest[0] eq "-1")
	 {
	  #
	  # We have a problem with connection and will stop
	  # here processing.
	  #
	  return ($ret_CompleteRequest[0],$ret_CompleteRequest[1]);
	 }

# Parse XML of SMS request
my $ret_parsed_response = parse_aspsms_response(\@ret_CompleteRequest,
						$aspsmst_transaction_id);

my $DeliveryStatus      =       XML::Smart->new($ret_parsed_response);
my $ErrorCode           =       $DeliveryStatus->{aspsms}{ErrorCode};
my $ErrorDescription    =       $DeliveryStatus->{aspsms}{ErrorDescription};
my $CreditsUsed         =       $DeliveryStatus->{aspsms}{CreditsUsed};

##########################################################################
# Generate ShowCredits Request
##########################################################################

=head2

Finally this function calls again the aspsms xml interface to query
current credit balance. This is not in one query possible, that's 
because we do that in a second call.

=cut

my $Credits = ShowBalance($jid,$aspsmst_transaction_id);

aspsmst_log('debug',"id:$aspsmst_transaction_id exec_SendTextSMS(): ".
"return ($ErrorCode,$ErrorDescription,$Credits,$CreditsUsed,".
"$aspsmst_transaction_id)");

return (	$ErrorCode,
		$ErrorDescription,
		$Credits,
		$CreditsUsed,
		$aspsmst_transaction_id);

} ### END of exec_SendTextSMS()

1;

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006-2012 Marco Balmer <marco@balmer.name>

The Debian packaging is licensed under the 
GPL, see `/usr/share/common-licenses/GPL-2'.

=cut

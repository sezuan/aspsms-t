# aspsms-t by Marco Balmer <mb@micressor.ch> @2004
# http://web.swissjabber.ch/
# http://www.micressor.ch/content/projects/aspsms-t/
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

package ASPSMS::Connection;

use strict;
use vars qw(@EXPORT @ISA);
use Exporter;

@ISA                    = qw(Exporter);
@EXPORT                 = qw(exec_SendTextSMS ConnectAspsms DisconnectAspsms exec_ConnectionASPSMS parse_aspsms_response);

use config;
use IO::Socket;
use ASPSMS::aspsmstlog;
use ASPSMS::xmlmodel;
use ASPSMS::Regex;


use Sys::Syslog;

openlog($config::ident,'','user');





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
	($mess,$number,$signature) 	= regexes($mess,$number,$signature);
        aspsmst_log('notice',"id:$aspsmst_transaction_id exec_SendTextSMS(): Begin");

	# Generate SMS Request
	my $aspsmsrequest;
	$aspsmsrequest = xmlSendTextSMS(	$login,
						$password,
						$phone,
						$number,
						$mess,
						$aspsmst_transaction_id ,
						$jid,
						$numbernotification,
						$config::affiliateid,
						$msg_id,
						$msg_type);

	my $completerequest     = xmlGenerateRequest($aspsmsrequest);
	my @ret_CompleteRequest = exec_ConnectionASPSMS($completerequest,$aspsmst_transaction_id);

	if($ret_CompleteRequest[0] eq "-1")
	 {
	  #
	  # We have a problem with connection and will stop
	  # here processing.
	  #
	  return ($ret_CompleteRequest[0],$ret_CompleteRequest[1]);
	 }

# Parse XML of SMS request
my $ret_parsed_response = parse_aspsms_response(\@ret_CompleteRequest,$aspsmst_transaction_id);

my $DeliveryStatus      =       XML::Smart->new($ret_parsed_response);
my $ErrorCode           =       $DeliveryStatus->{aspsms}{ErrorCode};
my $ErrorDescription    =       $DeliveryStatus->{aspsms}{ErrorDescription};
my $CreditsUsed         =       $DeliveryStatus->{aspsms}{CreditsUsed};

##########################################################################
# Generate ShowCredits Request
##########################################################################

$aspsmsrequest          = xmlShowCredits($login,$password);
$completerequest     = xmlGenerateRequest($aspsmsrequest);

my @ret_CompleteRequest_ShowCredits = exec_ConnectionASPSMS($completerequest,$aspsmst_transaction_id);

# Parse XML of SMS request
my $ret_parsed_response_ShowCredits = parse_aspsms_response(\@ret_CompleteRequest_ShowCredits,$aspsmst_transaction_id);

DisconnectAspsms($aspsmst_transaction_id);

my $CreditStatus        =       XML::Smart->new($ret_parsed_response_ShowCredits);
my $Credits             =       $CreditStatus->{aspsms}{Credits};


aspsmst_log('notice',"id:$aspsmst_transaction_id exec_SendTextSMS(): return ($ErrorCode,$ErrorDescription,$Credits,$CreditsUsed,$aspsmst_transaction_id)");
return ($ErrorCode,$ErrorDescription,$Credits,$CreditsUsed,$aspsmst_transaction_id);
########################################################################
}
########################################################################

sub exec_ConnectionASPSMS
 {
  my $completerequest = shift;
  my $aspsmst_transaction_id = shift;
  aspsmst_log('debug',"id:$aspsmst_transaction_id exec_ConnectionASPSMS(): Begin");
	
  # /Generate SMS Request
  unless(ConnectAspsms($aspsmst_transaction_id) eq '0') 
   { return ('-1',"Sorry, $config::ident transport is up and running but it is not able to reach one of the aspsms servers for delivering your sms message. Please try again later. Thank you!"); }
 
  # Send request to socket
  aspsmst_log('debug',"id:$aspsmst_transaction_id exec_ConnectionASPSMS(): Sending: $completerequest");
  print $config::aspsmssocket $completerequest;

  my @answer;

  eval 
   {
    # Timeout alarm
    alarm(10);
    @answer = <$config::aspsmssocket>;
    aspsmst_log('debug',"id:$aspsmst_transaction_id exec_ConnectionASPSMS(): \@answer=@answer");
    alarm(0);
   };

   # If alarm do action
   if($@) 
    {
     aspsmst_log('info',"id:$aspsmst_transaction_id exec_ConnectionASPSMS(): No response of aspsms after sent request");
     return ('-21','exec_ConnectionASPSMS(): No response of aspsms after sent request. Please try again later or contact your transport administrator.');
    } ### END of exec_ConnectionASPSMS ###

    DisconnectAspsms($aspsmst_transaction_id);
    aspsmst_log('notice',"id:$aspsmst_transaction_id exec_ConnectionASPSMS(): End");
    return (@answer);
 } ### END of exec_ConnectionASPSMS ###


########################################################################
sub ConnectAspsms {
########################################################################
my $aspsmst_transaction_id = shift;

my $status		= undef;
my $connect_retry 	= 0;
my $max_connect_retry	= 4;
my $connection_num	= 0;

#
# If connection failed we are trying to reconnect on another
# aspsms xml server
#

while ()
 {
  #
  # Select on of the 4 servers
  #
  $connection_num++;


  aspsmst_log('info',"id:$aspsmst_transaction_id ConnectAspsms(): Connecting to server $connection_num (".$config::aspsms_connection{"host_$connection_num"}.":".$config::aspsms_connection{"port_$connection_num"}.") \$connect_retry=$connect_retry");

  #
  # Setup a socket connection to the selected
  # server
  # 
  $config::aspsmssocket = IO::Socket::INET->new(     	PeerAddr => $config::aspsms_connection{"host_$connection_num"},
                                        		PeerPort => $config::aspsms_connection{"port_$connection_num"},
                                        		Proto    => 'tcp',
                                        		Timeout  => 3,
                                        		Type     => SOCK_STREAM) or $status = -1;

  aspsmst_log('debug',"id:$aspsmst_transaction_id ConnectAspsms(): status=$status");
  
  #
  # Increment connection retry
  #
  $connect_retry++;

  aspsmst_log('debug',"id:$aspsmst_transaction_id ConnectAspsms(): \$status=$status \$connection_retry=$connect_retry");

  if($connect_retry > $max_connect_retry)
   {
    aspsmst_log('info',"id:$aspsmst_transaction_id ConnectAspsms(): status=$status Max connect retry reached");
    last; 
   }

  if($status == -1)
   { 
    aspsmst_log('info',"id:$aspsmst_transaction_id ConnectAspsms(): Connecting to server $connection_num (".$config::aspsms_connection{"host_$connection_num"}.":".$config::aspsms_connection{"port_$connection_num"}.") failed \$status=$status \$connect_retry=$connect_retry");
    $status = undef;
   }
  else
   {
    #
    # Return connection sucessfully
    #
    return 0;
   }

   $status = undef; 
  } ### END of 


return $status;
}

sub DisconnectAspsms {
my $aspsmst_transaction_id = shift;
aspsmst_log('notice',"id:$aspsmst_transaction_id DisconnectAspsms()");
close($config::aspsmssocket);

########################################################################
}
########################################################################

sub parse_aspsms_response
 {
   my $pointer_xml 			= shift;
   my $aspsmst_transaction_id 		= shift;
   my @xml				= @{$pointer_xml};
   my $tmp;

   foreach $_ (@xml)
    {
     aspsmst_log("debug","id:$aspsmst_transaction_id parse_aspsms_response(): $_");
     $tmp .= $_;
    }
   
   $tmp =~ s/(.*(<aspsms>.*<\/aspsms>).*|.*)/$2/gis;
   aspsmst_log("notice","id:$aspsmst_transaction_id parse_aspsms_response(): Return: $tmp");
   return $tmp;
 }

1;


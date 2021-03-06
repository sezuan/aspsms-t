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

aspsms-t - jabber disco service presendation


=head1 DESCRIPTION

This module shows via jabber disco service which networks are supported
and how much cost an sms to a number.

=head1 METHODS

=cut

package ASPSMS::DiscoNetworks;

use strict;
use vars qw(@EXPORT @ISA);

use Exporter;
use Sys::Syslog;

use ASPSMS::config;
use ASPSMS::aspsmstlog;

openlog($ASPSMS::config::ident,'','user');


@ISA 				= qw(Exporter);
@EXPORT 			= qw(disco_get_aspsms_networks);



sub disco_get_aspsms_networks
{
 my $iqQuery	= shift;
 my $from	= shift;
 my $to		= shift;

=head2 disco_get_aspsms_networks($iqQuery,$from,$to)

iqQueries (jabber information queries) are routed directly to this function.
If a jabber user browse through the service discovery browser and look into
the aspsms-t service. This function shows all supported networks and
number prefix and sms costs.

=cut

      my @countries	= $ASPSMS::config::xml_networks->{networks}{country}('[@]','name');

      #
      # Generate disco item for each country
      #
      if($to eq "countries\@".$ASPSMS::config::service_name)
      {
       foreach my $i (@countries)
       {
        aspsmst_log('debug',"disco_get_aspsms_networks($from): Country: $i");
        $i =~ tr/A-Z/a-z/;
        
        #
        # Jid fix for spaces in country names
        #
        $i =~ s/\s/\_/g;
        unless($i eq "")
         {
          $iqQuery->AddItem(	jid=>"$i\@".$ASPSMS::config::service_name,
        			name=>$i);
         } ### END of unless($li eq "")
       } ### END of foreach my $i (@countries)
      } ### END of if($to eq "countries\@⅛.$ASPSMS::config::service_name")

    my @select_country = split(/@/,$to);
    if($to eq $select_country[0]."@".$ASPSMS::config::service_name)
     {
      
      #
      # Jid fix for spaces in country names
      #
      $select_country[0] =~ s/\_/\ /g;

      aspsmst_log('debug',"disco_get_aspsms_networks($from): Display network of country ".$select_country[0]);

      #
      # Change country to uppercase
      #
      $select_country[0] =~ tr/a-z/A-Z/;
      my @networks	= $ASPSMS::config::xml_networks->{"networks"}{"country"}('name','eq',"$select_country[0]"){"network"}('[@]','name');
      my @credits	= $ASPSMS::config::xml_networks->{"networks"}{"country"}('name','eq',"$select_country[0]"){"network"}('[@]','credits');

      my @prefixes;

      my $counter_networks 	=0;
      my $counter_prefixes	=0;
      foreach my $i (@networks)
      {
       @prefixes = $ASPSMS::config::xml_fees->{"fees"}{"country"}('name','eq',"$select_country[0]"){"network"}('name','eq',"$i"){"prefix"}('[@]','number');

       #
       # Generate disco item for each country
       #
       aspsmst_log('debug',"disco_get_aspsms_networks($from): Network $counter_networks: $i");

       unless($i eq "")
	{
	 $i =~ s/\s/\_/g;
         $iqQuery->AddItem(	name=>"Network: $i",
	 			jid=>"$i\@$ASPSMS::config::service_name");
	 $i =~ s/\_/\s/g;
        } ### END of unless($i eq "")


       $counter_prefixes	=0;
       foreach my $i_prefix (@prefixes)
        {
         #
         # Generate disco item for prefixes
         #
	 unless($i_prefix eq "")
	  {
           aspsmst_log('debug',"disco_get_aspsms_networks($from): Prefix $counter_prefixes: $i_prefix");
	   
           $iqQuery->AddItem(
	name=>"Network prefix: $i_prefix [Credits:$credits[0]]",
	jid=>"$i_prefix\@$ASPSMS::config::service_name");
	  }
	 $counter_prefixes++;
	} ### END of foreach my $i (@prefixes)
       $counter_networks++;
      } ### END of foreach my $i (@countries)

     } ### END of if($to eq "networks\@$ASPSMS::config::service_name")

 return $iqQuery;
} ### END of disco_get_aspsms_networks ###

1;

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006-2012 Marco Balmer <marco@balmer.name>

The Debian packaging is licensed under the 
GPL, see `/usr/share/common-licenses/GPL-2'.

=cut

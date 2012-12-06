#!/usr/bin/perl

use strict;
use warnings;

use Socket;
use Data::Dumper;
use Fcntl qw(F_GETFL F_SETFL O_NONBLOCK);

use fcgihandler;
#	my $rec_len = length($r);
#
#
#	my $request_variables = {};
#
#	while ($idx < $rec_len) {
#
#		print "idx: $idx\n";
#
#		my @l = unpack("CCnnCC", substr($r, $idx, $rec_len - $idx));
#
#
#		my $req = {
#
#			"ver" => $l[0],
#			"type" => $l[1],
#			"req_id" => $l[2],
#			"cont_len" => $l[3],
#			"pad_len" => $l[4],
#			"res" => $l[5],
#		};
#
#		print " = = = " . $fcgi_req_types->{$req->{"type"}} . " = = =\n";
#		printf("ver: %d, type: %d, req_id: %d, cont_len: %d, pad_len: %d, res: %d\n", @l);
#
#		if ($req->{'type'} == 1) {
#			
#			
#
#
#		} elsif ($req->{'type'} == 4) {
#
#
#			}
#
#			$idx += $req->{'cont_len'} + $req->{'pad_len'};
#
#		} elsif ($req->{'type'} == 0) {
#			exit(0);
#		}
#
#
#
#		#print Dumper(\@l);
#	}
#
#	my $resp = "";
#
#	my $tmp = "Content-type: text/html\r\n\r\n<html>\n<head>ulalalal cos zaczyna dziakac";
#
#	$resp = chr(1) . chr(6) . chr(0) . chr(1) . chr(0) . chr(length($tmp)) . chr(0) . chr(0) . $tmp;
#	$resp .= chr(1) . chr(6) . chr(0) . chr(1) . chr(0) . chr(0)           . chr(0) . chr(0);
#
#
#
##unsigned char appStatusB3;
##    unsigned char appStatusB2;
##    unsigned char appStatusB1;
##    unsigned char appStatusB0;
##    unsigned char protocolStatus;
##    unsigned char reserved[3];
#	$resp .= chr(1) . chr(3) . chr(0) . chr(1) . chr(0) . chr(8) . chr(0) . chr(0)  . 
#		(chr(0) x 8);
#
#	my $wr = syswrite $c, $resp, length($resp);
#
#	print "zapisano: $wr bajtow\n";
#
##	{FCGI_STDOUT,      1, "Content-type: text/html\r\n\r\n<html>\n<head> ... "}
##	{FCGI_STDOUT,      1, ""}
##	{FCGI_END_REQUEST, 1, {0, FCGI_REQUEST_COMPLETE}}
#
#
#	print "to koniec?\n";
#	print Dumper($request_variables);
#	exit(0);
#
#
#	my @args = (split /\r/, $r);


my $fcgi_req_types = {
	1 => 'FCGI_BEGIN_REQUEST',    
	2 => 'FCGI_ABORT_REQUEST',       
	3 => 'FCGI_END_REQUEST',         
	4 => 'FCGI_PARAMS',              
	5 => 'FCGI_STDIN',               
	6 => 'FCGI_STDOUT',              
	7 => 'FCGI_STDERR',              
	8 => 'FCGI_DATA',                
	9 => 'FCGI_GET_VALUES',          
	10 => 'FCGI_GET_VALUES_RESULT',  
	11 => 'FCGI_UNKNOWN_TYPE',       
};




# funkcja, ktora otrzymuje na wejsciu dane ze strumienia, pozycje w tym strumieniu
# 

socket my $s, PF_INET, SOCK_STREAM, getprotobyname("tcp") or die("blad tworzenia socketa");

print Dumper($s);

setsockopt($s, SOL_SOCKET, SO_REUSEADDR, pack("l", 1)) ;

bind($s, sockaddr_in(8080, INADDR_ANY)) || die "bind: $!";
listen($s, 256);


my $paddr;


	#recv SOCKET,SCALAR,LENGTH,FLAGS 

	


	my $r;

	my ($idx, $buf, $total_len) = (0, "", 0);

	my $fh = {};

	$fh->{fileno($s)} = {
		"socket" => $s,
		"type" => "listener",
		"obj" => undef,
	};

	
	my ($rin, $win, $ein) = ('', '', '');

	while (1) {

		$rin = '';

		foreach (keys %{$fh}) {
			print "zaznaczam do odczytu: $_\n";
			vec($rin, $_, 1) = 1;
		}	


		#vec($win, fileno(STDOUT), 1) = 1;

		my ($rout, $wout, $eout);

		my $nfound = 0;
		while ($nfound <= 0) {
			$nfound = select($rout = $rin, $wout = $win, $eout = $ein, undef);

			print "po select... ($nfound) $!\n";
			if ($nfound == -1) {

				sleep(1);
			}
		}

#sleep(1);

		print "po select, nfound: $nfound, " . ord($rout) . "; " . ord($wout) . "\n";

		for (my $i = 0; $i < (length($rout) * 8); $i++) {
			if (vec($rout, $i, 1) > 0) {
				print "deskr: $i\n";
				if (defined($fh->{$i})) {
					if ($fh->{$i}->{'type'} eq "client") {

						print "typ to klient\n";
						my $r;
						my $bytes = sysread($fh->{$i}->{"socket"}, $r, 1024) || 0;

						if (!$bytes) {
							print "rozlaczam klienta: $!\n";

							$fh->{$i}->{'obj'}->disconnect_handler();
							close($fh->{$i}->{'socket'});
							delete $fh->{$i};

							vec($rin, $i, 1) = 0;
							vec($win, $i, 1) = 0;

						} else {

						
							print "odebrano bajtow: $bytes\n";

							my $bytes_handled = 0;
							my $bytes_left = $bytes;
#
#						while (1) {

							$bytes_handled = $fh->{$i}->{"obj"}->recv_handler(substr($r, $bytes_handled, $bytes_left), $bytes_left);

							print " = = = klient chce cos wyslac = = = =\n";

#print Dumper($bytes_handled);

							if (defined($bytes_handled)) {

								foreach (keys %{$bytes_handled}) {

									if (!defined($_) || length($_) <= 0) {

										print Dumper($bytes_handled);
										die('wutf?');
									}

									vec($win, $_, 1) = 1;

									$fh->{$_}->{"tosend"} .= $bytes_handled->{$_}->{'data'}; 


								}
							}

#							last if (!$bytes_handled);

#							last if (!($bytes_handled - $bytes));


#							$bytes_left -= $bytes_handled;

#							print "pozostalo do obslugi: " . ($bytes - $bytes_handled) . "\n";

						}

#					}

					} elsif ($fh->{$i}->{'type'} eq "listener") {
						print "nowe polaczenie przychodzace\n";
						$paddr = accept(my $c, $fh->{$i}->{"socket"});

						my $flags;
						$flags = fcntl($c, F_GETFL, 0) || die $!;
						$flags |= O_NONBLOCK;
						fcntl($c, F_SETFL, $flags) || die $!;

						my $h = new FcgiHandler(\$c);

#$h->socket_set(\$c);

						my($port, $iaddr) = sockaddr_in($paddr);

						print "connection from [", inet_ntoa($iaddr), "] at port $port\n";

						$fh->{fileno($c)} = {
							"socket" => $c,
							"type" => "client",
							"obj" => $h,
						};

						print "dodano klienta\n";


				} else {
					die("nie wiem co to za klient?");

				}
			}
		
		}

		if (vec($wout, $i, 1) > 0) {
			
			print "handler write dla $i\n";

			if (!defined($fh->{$i})) {
				vec($win, $i, 1) = 0;
				next;
			}

			my $towrite = length($fh->{$i}->{'tosend'} || '');

			if ($towrite > 1024) {
				$towrite = 1024;
			}


			
			if ($towrite > 0) {

				my $wr = syswrite $fh->{$i}->{'socket'}, $fh->{$i}->{'tosend'}, $towrite;
				print ">>> wyslano: $wr bajtow\n";

				if ((length($fh->{$i}->{'tosend'}) - $towrite) > 0) {
					$fh->{$i}->{'tosend'} = substr($fh->{$i}->{'tosend'}, $towrite, (length($fh->{$i}->{'tosend'}) - $towrite));
				} else {

					$fh->{$i}->{'tosend'} = "";
					print "nie ma wiecej danych do wyslania od tego klienta\n";
#					vec($win, $i, 1) = 0;
				}


				if ($towrite != $wr) {

					print "cos poszlo nie tak :(\n";
				}
			} else {

				print "Zamykam socket: " . fileno($fh->{$i}->{'socket'}) . "\n";
				$fh->{$i}->{'obj'}->disconnect_handler();
				close($fh->{$i}->{'socket'});
				delete $fh->{$i};

				vec($rin, $i, 1) = 0;
				vec($win, $i, 1) = 0;
			}



		}
	}
		
	


#	print Dumper(\@args);

	#print "odebrano: $r\n";


}

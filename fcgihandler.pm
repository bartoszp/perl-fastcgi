package FcgiHandler;

use Data::Dumper;
use strict;
use warnings;


use constant {


	INITIAL_STATE => 1,
	READING_PARAMETERS => 2,
	WRITING_RESPONSE => 3,

	WAITING_FOR_EVENT => 10,
	
	FCGI_BEGIN_REQUEST  =>   1,
	FCGI_ABORT_REQUEST  =>   2,
	FCGI_END_REQUEST    =>   3,
	FCGI_PARAMS         =>   4,
	FCGI_STDIN          =>   5,
	FCGI_STDOUT         =>   6,
	FCGI_STDERR         =>   7,
	FCGI_DATA           =>   8,
	FCGI_GET_VALUES     =>   9,
	FCGI_GET_VALUES_RESULT=>10,
	FCGI_UNKNOWN_TYPE   =>  11,
};

our $instances = {};
our $instance_count = 0;

sub new {

	my ($self, $socket) = @_;

#print "create fcgihandler, self: $self, socket: $socket\n";

	$self = {

		'state' => INITIAL_STATE,
		'sub_state' => 0,

		'buf_pos' => 0,
		'buf' => "",

		'buf_length' => 0,

		'request_variables' => {},

		'socket' => $socket,
		'id' => $instance_count,

		# parametry z query string
		'parameters' => {},
	};

	bless $self, 'FcgiHandler';

	$instances->{$instance_count} = $self;
	$instance_count++;

	return $self;
}

sub socket_set {
	my ($self, $socket) = @_;

	$self->{'socket'} = $socket;
}

sub hexdump {

	my ($self, $buf, $pos, $len) = @_;

	my $idx = 0;

	for ($idx = 0; $idx < $len; $idx++) {
		if (!($idx % 16)) {
			print "\n";
			printf("%04d ", $idx);
		}
		print ord(substr($buf, $idx, 1)) . " ";
	}
}

sub get_req_hdr {
	my ($self, $buf, $idx) = @_;

	my @l = unpack("CCnnCC", substr($buf, $idx, 8));

	my $req_hdr = {

		"version" => $l[0],
		"type" => $l[1],
		"request_id" => $l[2],
		"content_length" => $l[3],
		"padding_length" => $l[4],
		"reserved" => $l[5],
	};

	return $req_hdr;

}

sub parse_query_string {

	my $self = shift;

	my $qs = $self->{'request_variables'}->{'QUERY_STRING'} || "";

	print "qs: $qs\n";

	while ($qs =~ m/(.+?)=(.+)/g) {

		$self->{'parameters'}->{$1} = $2;
	}

}

sub generate_response {

	my $self = shift;
	my $content = shift;

	my $tmp = "Content-type: text/html\r\n\r\n$content";

	my $resp = chr(1) . chr(6) . chr(0) . chr(1) . chr(0) . chr(length($tmp)) . chr(0) . chr(0) . $tmp;
	$resp .= chr(1) . chr(6) . chr(0) . chr(1) . chr(0) . chr(0)           . chr(0) . chr(0);


	$resp .= chr(1) . chr(3) . chr(0) . chr($self->{'request_id'}) . chr(0) . chr(8) . chr(0) . chr(0)  . 
		(chr(0) x 8);

	print "generuje id dla klienta: " . $self->{'request_id'} . "\n";

	return $resp;

}

sub recv_handler {

	my ($self, $buf, $len) = @_;

	my $handled = 0;

	print "\n!!!!\n########################\n recv_handler($len)\n";

	$self->{'buf'} .= $buf;
	$self->{'buf_length'} += $len;

	MAIN: while (1) {

		print "buf_pos: " . $self->{'buf_pos'} . "; buf_length: " . $self->{'buf_length'} . "\n";

		

		my ($state_c, $state_n) = ($self->{'state'}, $self->{'state'});

		if ($state_c == INITIAL_STATE) {
			print "initial state\n";
			if ($self->{'buf_pos'} == 0) {
				if ($self->{'buf_length'} < 16) {
					last MAIN;
				}
				print "buf_pos == 0\n";


				# pierwszy powinien byc BEGIN_REQUEST

				my $hdr = $self->get_req_hdr($buf, 0);

				$self->{'request_id'} = $hdr->{'request_id'};

				print "length: " . $hdr->{'content_length'} . "; padding: " . $hdr->{'padding_length'} . "\n";
				print "id: " . $self->{'request_id'} . "\n";

				die('pierwszy odebrany rekord powinien byc typu FCGI_BEGIN_REQUEST') if ($hdr->{'type'} != FCGI_BEGIN_REQUEST);
				die('content length w pierwszym pakiecie powinien wynosic 8') if ($hdr->{'content_length'} != 8);

				my ($role, $flags) = unpack('nc', substr($self->{'buf'}, 8, 8));

				print "rola: $role, flagi: $flags\n";

				$self->{'buf_pos'} += 16;

				$state_n = READING_PARAMETERS;

				$self->{'buf_pos'} = 16;
				$handled = 16;

			}

		} elsif ($state_c == READING_PARAMETERS) {
			print "stan: reading_parameters\n";

				
				my $hdr = $self->get_req_hdr($buf, $self->{"buf_pos"});

				my $left = $hdr->{'content_length'};
				my $total = $left;

				$self->{'buf_pos'} += 8;

				if ($hdr->{'content_length'} > 0) {

					print "total: $total\n";
					print "padding: " . $hdr->{'padding_length'};



					while ($left > 0) {
						print "left: $left\n";

						my ($name_hdr_len, $val_hdr_len) = (1, 1);

						my ($name_len) = unpack('C', substr($self->{'buf'}, $self->{'buf_pos'}, 1));

						if ($name_len & 0x80) {
							$name_len = unpack('N', substr($self->{'buf'}, $self->{'buf_pos'}, 4));
							$name_len &= 0x7fffffff;

							$name_hdr_len = 4;
						}

						$self->{'buf_pos'} += $name_hdr_len;
						$left -= $name_hdr_len;

						my $val_len = unpack('C', substr($self->{'buf'}, $self->{'buf_pos'}, 1));

						if ($val_len & 0x80) {
							$val_len = unpack('N', substr($self->{'buf'}, $self->{'buf_pos'}, 4));
							$val_len &= 0x7fffffff;

							$val_hdr_len = 4;
						}

						$self->{'buf_pos'} += $val_hdr_len;
						$left -= $val_hdr_len;

						#printf ("w nagl. dl. nazwy: %d, dl wart: %d\n", $name_hdr_len, $val_hdr_len);

						#print "dlugosc nazwy parametry: " . $name_len . "; dlugosc wartosci parametru: " . $name_len . "\n";

#printf("parametr: (%s)\n", substr($, $idx, $name_len));
#				printf("wartosc:  (%s)\n", substr($r, $idx + $name_len, $val_len));

						$self->{'request_variables'}->{substr($self->{'buf'}, $self->{'buf_pos'}, $name_len)} = substr($self->{'buf'}, $self->{'buf_pos'}+ $name_len, $val_len);

						$left -= $name_len + $val_len;
						$self->{'buf_pos'} += $name_len + $val_len;

						if ($left <= 0) {
							print "LEFT MA: $left\n";
						}

					}

					$handled = $total + 8 + $hdr->{'padding_length'};
					$self->{'buf_pos'} += $hdr->{'padding_length'};

				} else {

					print Dumper($self->{'request_variables'});

					print "przeczytano wszystkie parametry\n";


					$self->{'buf_pos'} += 8;

					$state_n = WRITING_RESPONSE;

					$self->parse_query_string();
				}




		} elsif ($state_c == WRITING_RESPONSE) {


			print "WRITING RESPONSE\n";

			my $qs = $self->{'request_variables'}->{'QUERY_STRING'} || "";

			if ($qs =~ "^listen") {

				$self->{'state'} = WAITING_FOR_EVENT;
				return;

			} elsif ($qs =~ "^push") {

#my $ret = 

				my $ret = {};

				foreach (keys %{$instances}) {

					my $t = $instances->{$_};

					print "pacze na $_, socket: " . fileno(${$t->{'socket'}}) . "\n";
					print "KLIENT OD ID: " . $t->{'request_id'} . "\n";

					if ($t->{'state'} == WAITING_FOR_EVENT) {
						print Dumper($self->{'parameters'});
						print "wiadomosc: " . $self->{'parameters'}->{'push'} . "\n";
						print "! ! ! znalazlem klienta, ktoremu mozna cos wyslac\n";

						print "--- " . ${$t->{'socket'}}. "\n";
						print "!!! dodalem, jego ID: (1) " . fileno(${$t->{'socket'}}) . ";" . ${$t->{'socket'}}. "\n";
						$ret->{fileno(${$t->{'socket'}})} = {
							"object" => $t,
							"data" => $instances->{$_}->generate_response("msg: " . $self->{'parameters'}->{'push'}),
						};

					}


				}
				print "!!! dodalem siebie, jego ID: (2) " . fileno(${$self->{'socket'}}) . ";" . ${$self->{'socket'}} . "\n";

				$ret->{fileno(${$self->{'socket'}})} = {"object" => $self, "data" => $self->generate_response("msg: " . $self->{'parameters'}->{'push'})};

				return $ret;


			} else {

				print "nieznane query string\n";
				die();
			}

#print Dumper($self->get_req_hdr($buf, $self->{"buf_pos"}));

#			$self->hexdump($self->{'buf'}, $self->{'buf_pos'}, $len);


		} elsif ($state_c == WAITING_FOR_EVENT) {

			print "WAITING_FOR_EVENT - tu sie nie powinnismy zjawic\n";

		
		} else {
			die('nieznany stan?');
		}

		$self->{'state'} = $state_n;


		print "KUNIEC\n";
#sleep(1);
	}

}

sub disconnect_handler {

	my $self = shift;

	print "disconnect handler...\n";

	delete $instances->{$self->{'id'}};
}

sub write_handler {

	

}

1;

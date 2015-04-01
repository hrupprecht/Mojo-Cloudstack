package Mojo::Cloudstack;

use Mojo::Base 'Mojo::UserAgent';
use Mojo::Parameters;
use Mojo::URL;
use Mojo::UserAgent;
use Mojo::JSON 'j';
use Mojo::Collection 'c';
use Mojo::Cloudstack::Base;
use Digest::HMAC_SHA1 qw(hmac_sha1 hmac_sha1_hex);
use MIME::Base64;
use URI::Encode 'uri_encode';
use Data::Dumper 'Dumper';

has 'host'        => "localhost";
has 'path'        => "/client/api";
has 'port'        => "8080";
has 'scheme'      => "https";
has 'api_key'     => "";
has 'secret_key'  => "";
has '_req'        => '';
has '_res'        => '';

our $VERSION = '0.01';
our $AUTOLOAD;

sub _build_request {
  my ($self, $params) = @_;
  my $baseurl = sprintf ("%s://%s:%s%s?", $self->scheme, $self->host, $self->port, $self->path);
  $params->{ apiKey }   = $self->api_key;
  $params->{ response } = 'json';
  my $secret_key = $self->secret_key;

  my $req_params = Mojo::Parameters->new();
  foreach my $p (sort keys %$params) {
    $req_params->param($p => uri_encode($params->{ $p }));
  }
  my $params_str = lc ($req_params->to_string);
  my $digest = hmac_sha1($params_str, $secret_key);
  my $base64_encoded = encode_base64($digest);
  chomp ($base64_encoded);

  my $uri_encoded = uri_encode($base64_encoded,1);
  my $url = Mojo::URL->new($baseurl);
  $url->query($req_params->to_string);

  return $url->to_string . '&signature='.$uri_encoded;

}

sub AUTOLOAD {
  my $self = shift;
  (my $command = $AUTOLOAD) =~ s/.*:://;
  my %params = @_;
  $params{command} = $command;
  my $req = $self->_build_request(\%params);
  $self->_req($req);
  my $items = $self->get($req)->res->json;
  die "Could not get response for $req " . $self->status unless $items;
  my $responsetype = (keys %$items)[0];
  if($responsetype =~ /^(list)(.*)(response)$/){
    my ($otype, $oname, $oresponse) = ($1, $2, $3);
    if($oname =~ /(s$)/){
      $oname =~ s/$1//;
    }
    if($otype eq 'list'){
      return c(
        map { Mojo::Cloudstack::Base->new('Mojo::Cloudstack::' . ucfirst($oname),$_) } @{$items->{$responsetype}{$oname}}
      );
    }
  } else {
    die "unknown response type $responsetype";
  }

      #$self->_ua->get($req => sub {
      #  my ($ua, $tx) = @_;
      #  return  $tx->res->body;
      #});
}

1;

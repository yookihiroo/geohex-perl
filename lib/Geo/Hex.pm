package Geo::Hex;
use warnings;
use strict;
BEGIN {
    our (@EXPORT, @EXPORT_OK);
    use base qw(Exporter);
    @EXPORT = qw(getZoneByCode getZoneByLocation getZonesByExtent);
    @EXPORT_OK = qw(calc_hex_size get_level loc2xy xy2pos pos2code code2pos pos2xy xy2loc);
}

use Geo::Hex::Zone;

use POSIX qw(floor ceil);
use Math::Round qw(round);
use Math::Trig qw(pi tan atan);
use Math::BaseCalc;

my $h_base = 20037508.34;
my $h_k = tan(pi * (30 / 180));

my $base3 = new Math::BaseCalc(digits => [0..2]);
my $base30 = new Math::BaseCalc(digits => ['A'..'Z', 'a'..'d']);
# private methods
sub encode3 {
    my ($pos, $size) = @_;
    my $max = 3 ** $size;
    my $rev = floor($pos + $max / 2);
    return '0' x $size if $rev < 0;
    return '2' x $size if $rev >= $max;
    my $format = "%0${size}s";
    sprintf($format, $base3->to_base($rev));
}
sub decode3 {
    my ($code, $size) = @_;
    my $val = $base3->from_base($code);
    my $max = 3 ** $size;
    $val - floor($max / 2);
}
# Zone friendly methods
sub loc2xy {
    my ($lon, $lat) = @_;
    my $x = $lon * $h_base / 180;
    my $y = log(tan((90 + $lat) * pi / 360)) / (pi / 180);
    $y *= $h_base / 180;
    +{x => $x, 'y' => $y};
}
sub xy2pos {
    my ($x, $y, $level) = @_;
    my $h_size = calc_hex_size($level);
    my $unit_x = 6 * $h_size;
    my $unit_y = 6 * $h_size * $h_k;
    my $h_pos_x = ($x + $y / $h_k) / $unit_x;
    my $h_pos_y = ($y - $h_k * $x) / $unit_y;
    my $h_x_0 = floor($h_pos_x);
    my $h_y_0 = floor($h_pos_y);
    my $h_x_q = $h_pos_x - $h_x_0;
    my $h_y_q = $h_pos_y - $h_y_0;
    my $h_x = round($h_pos_x);
    my $h_y = round($h_pos_y);
    if ($h_y_q > -$h_x_q + 1) {
        if (($h_y_q < 2 * $h_x_q) && ($h_y_q > 0.5 * $h_x_q)) {
            $h_x = $h_x_0 + 1;
            $h_y = $h_y_0 + 1;
        }
    } elsif ($h_y_q < -$h_x_q + 1) {
        if (($h_y_q > (2 * $h_x_q) - 1) && ($h_y_q < (0.5 * $h_x_q) + 0.5)) {
            $h_x = $h_x_0;
            $h_y = $h_y_0;
        }
    }
    my $h_lat = ($h_k * $h_x * $unit_x + $h_y * $unit_y) / 2;
    my $h_lon = ($h_lat - $h_y * $unit_y) / $h_k;

    my $z_loc = xy2loc($h_lon, $h_lat);
    if ($h_base - $h_lon < $h_size) {
        $z_loc->{lon} = 180;
        my $h_xy = $h_x;
        $h_x = $h_y;
        $h_y = $h_xy;
    }
    +{ x => $h_x, 'y' => $h_y };
}
sub pos2code {
    my ($x, $y, $level) = @_;
    my $size = $level + 3;
    my @basex = split(//, encode3($x, $size));
    my @basey = split(//, encode3($y, $size));
    my @code3 = map { $basex[$_]. $basey[$_] } 0..($size - 1);
    my @code9 = map { $base3->from_base($_) } @code3;
    my $h_code = join('', @code9);

    my $h_2 = substr($h_code, 3);
    my $h_1 = substr($h_code, 0, 3);
    $base30->to_base($h_1). $h_2;
}
sub code2pos {
    my $code = shift;
    my $c30 = $base30->from_base(substr($code, 0, 2));
    my $h_dec9 = $c30. substr($code, 2);
    if ($h_dec9 =~ /^([15])[^125](?:[^125])?/) {
        my $tmp = $1 == 5 ? 7 : 3;
        $h_dec9 = $tmp. substr($h_dec9, 1);
    }
    my $h_dec = join('', map {sprintf('%02d', $base3->to_base($_))} split('', $h_dec9));

    my (@x, @y, $i);
    for ($i = 0; $i < length($h_dec); $i+= 2) {
        push @x, substr($h_dec, $i, 1);
        push @y, substr($h_dec, $i + 1, 1);
    }
    my $level = get_level($code);
    my $size = $level + 3;
    my $h_x = join('', @x);
    my $h_y = join('', @y);
    my $x = decode3($h_x, $size);
    my $y = decode3($h_y, $size);
    +{ x => $x, 'y' => $y, dec9 => $h_dec9 };
}
sub pos2xy {
    my ($x, $y, $level) = @_;
    my $h_size = calc_hex_size($level);
    my $unit_x = 6 * $h_size;
    my $unit_y = 6 * $h_size * $h_k;
    my $h_y = ($h_k * $x * $unit_x + $y * $unit_y) / 2;
    my $h_x = ($h_y - $y * $unit_y) / $h_k;
    +{ x => $h_x, 'y' => $h_y };
}
sub xy2loc {
    my ($x, $y) = @_;
    my $lon = ($x / $h_base) * 180;
    my $lat = ($y / $h_base) * 180;
    $lat = 180 / pi * (2 * atan(exp($lat * pi / 180)) - pi / 2);
    if ($lon > 180) {
        $lon -= 360;
    } elsif ($lon < -180) {
        $lon += 360;
    }
    +{lon => $lon, lat => $lat};
}
sub calc_hex_size {
    my $level = shift;
    $h_base / 3 ** ($level + 3);
}
sub get_level {
    my $code = shift;
    length($code) - 2;
}
# public methods
sub getZoneByCode {
    my $code = shift;
    my $level = get_level($code);
    my $pos = code2pos($code);
    my $xy = pos2xy($pos->{x}, $pos->{y}, $level);
    my $loc = xy2loc($xy->{x}, $xy->{y});
    Geo::Hex::Zone->new(
        lat => $loc->{lat},
        lon => $loc->{lon},
        x => $pos->{x},
        'y' => $pos->{y},
        code => $code
    );
}
sub getZoneByLocation {
    my ($lat, $lon, $level) = @_;
    
    my $xy = loc2xy($lon, $lat);
    my $pos = xy2pos($xy->{x}, $xy->{y}, $level);
    my $code =  pos2code($pos->{x}, $pos->{y}, $level);
    Geo::Hex::Zone->new(
        lat => $pos->{lat},
        lon => $pos->{lon},
        x => $pos->{x},
        'y' => $pos->{y},
        code => $code
    );
}
sub getZonesByExtent {
    my ($x1, $y1, $x2, $y2, $level) = @_;
    my @rs;
    my $lb = xy2pos($x1, $y1, $level);
    my $rt = xy2pos($x2, $y2, $level);
    my $rb = xy2pos($x2, $y1, $level);
    my $lt = xy2pos($x1, $y2, $level);
    my $size = calc_hex_size($level) * 2;
    my ($x, $y);
    for ($y = $rb->{y}; $y <= $lt->{y}; $y += 1) {
        for ($x = $lb->{x}; $x <= $rt->{x}; $x += 1) {
            my $xy = pos2xy($x, $y, $level);
            next if $xy->{x} < $x1 - $size || $x2 + $size < $xy->{x} || $xy->{y} < $y1 - $size || $y2 + $size < $xy->{y};
            my $code = pos2code($x, $y, $level);
            push @rs, getZoneByCode($code);
        }
    }
    @rs;
}
1;

package Geo::Hex::Zone;
use warnings;
use strict;

use Math::Trig qw(pi tan);

use Geo::Hex qw(calc_hex_size get_level loc2xy xy2pos pos2code code2pos pos2xy xy2loc);

sub build_xy {
    my $self = shift;
    $self->{xy} = loc2xy($self->{lon}, $self->{lat}, $self->getLevel);
}
sub build_hex_coords {
    my $self = shift;
    $self->build_xy unless $self->{xy};
    my $h_x = $self->{xy}->{x};
    my $h_y = $self->{xy}->{y};
    my $h_deg = tan(pi * (60 / 180));
    my $level = $self->getLevel;
    my $h_size = calc_hex_size($level);
    my $h_top = xy2loc($h_x, $h_y + $h_deg *  $h_size)->{lat};
    my $h_btm = xy2loc($h_x, $h_y - $h_deg *  $h_size)->{lat};

    my $h_l = xy2loc($h_x - 2 * $h_size, $h_y)->{lon};
    my $h_r = xy2loc($h_x + 2 * $h_size, $h_y)->{lon};
    my $h_cl = xy2loc($h_x - 1 * $h_size, $h_y)->{lon};
    my $h_cr = xy2loc($h_x + 1 * $h_size, $h_y)->{lon};
    $self->{coords} = +[
        {lat => $self->{lat}, lon => $h_l},
        {lat => $h_top, lon => $h_cl},
        {lat => $h_top, lon => $h_cr},
        {lat => $self->{lat}, lon => $h_r},
        {lat => $h_btm, lon => $h_cr},
        {lat => $h_btm, lon => $h_cl}
        ];
}
sub new {
    my $class = shift;
    my %params = @_;
    bless +{
        lat => $params{lat},
        lon => $params{lon},
        x => $params{x},
        'y' => $params{y},
        code => $params{code},
        xy => undef,
        coords => undef
    }, $class;
}
sub getLevel {
    get_level(shift->{code});
}
sub getHexSize {
    my $self = shift;
    calc_hex_size($self->getLevel);
}
sub getHexCoords {
    my $self = shift;
    $self->build_hex_coords unless $self->{coords};
    $self->{coords};
}
1;

=head1 Deal Or No Deal

=begin html
<img src="https://github.com/saiftynet/DealOrNoDeal/blob/main/Screenshots/Version001.png">
=end html

=cut

use strict;
use warnings;
use Object::Pad;
use List::Util qw/shuffle/;

my $VERSION=0.001;

our $painter=Painter->new();

my $board=Board->new();
$board->draw();

=head2 BOARD
A Board object contains all the Box objects which contain Money objects
it's main purpose is to handle the user interface that diplays available
boxes and money left.

=cut

class Board {
   use List::Util qw/shuffle/;
   field $width :param=80;
   field $height :param=20;
   field @boxes;
   field $removed={};
   field %boxes;           
   field @screen;
   
=head3 BUILD()
Initialises the board and creates the Box objects each of which has a Money
object nserted inton it. during the build phase, Box locations are set to
positions that would fit into a minimal 80x24 ANSI terminal window 
=cut
               
   BUILD{  # initialise the board
	  # shuffle money and boxes and put money into each of 22 boxes
	  my @values=(1,10,50,100,500,1000,5000,10000,25000,50000,75000,
                  100000,200000,300000,400000,500000,750000,
                  1000000,2500000,5000000,7500000,10000000);
	  my @boxNos=shuffle (1..@values);
	  my $mSide="left";my $mRow=1;my $row=2;my $column=15;
	  foreach my $money(@values){
		 push @boxes, Box->new(number=>shift @boxNos, money=>Money->new(value=>$money,row=>$mRow++,side=>$mSide));
		 if ($mRow>@values/2){
			 $mRow=1;
			 $mSide="right"
		 }
		 $boxes[-1]->set_location({row=>$row,column=>$column});
		 $column+=9;
		 if ($column>($width-20)){
			 $column=15;
			 $row+=4;
		 }
	 };
	  }
=head3 draw()
draws the Board.  Simply loops through all the boxes and their contents
and draws them if they are available, then pouts the cursor at the bottom of the screen
=cut	  
	  method draw(){
		 foreach (@boxes){
			 $_->draw();
			 $_->money->draw(); 
		 };	
		 $painter->printAt(23,0,$painter->style("reset")." ");	  
	  }
}

=head2 Money
A Money object is inserted into each Box and is displayed.  Initilly it is 
$avaialble, but as boxes are opened, the value is removed  and not drawn. 
=cut

class Money {
	field $value    :param;
	field $row    :param;
	field $side   :param;
	field $available=1;
	field $colour;

=head3 remove()
$sets $available to 0, so it is skipped by the draw() function
=cut
	method remove(){
		$available=0;
	}

=head3 draw()
draws the Money.  Money has value in pence and this is converted into a label
a centered item is made ; calcualtion and drawing is complicated by the way the 
terminal may display characters and how perl reads them: e.g.
"£" counts as 2 characters in a but occupies one space
"◀","▶" occupies two spaces but counts as one character
=cut	
	method draw(){
		return unless $available;
		my $label=($value<100)  ? 	((length $value)%2?"":" ").$value.'p':
		                            ((length $value)%2?" ":"").' £'.($value/100);
		my $colour=$value<100000?"blue":"magenta";
		my @decs=($painter->decorate($colour),
			       $painter->decorate("white,on_$colour"),
			       $painter->decorate("reset,$colour,on_black"),
			       $painter->decorate("reset"));
		my $padding=" "x((9-length $label)/2);
		$label="$decs[0]◀ ".$decs[1].$padding.$label.$padding."$decs[2]▌▶ $decs[3]";
		$painter->printAt($row*2,($side eq "left"?2:68),$label);
	}
}

=head2 Box
A Box object is created by the Board object and contains a Money object
if uunopened it is drawn  on the Board Object.  Once opened the Box is removed
and the money is made no longer avalable.  It has a location and is displayed 
on the board at that location. 
=cut

class Box{
	field $number :reader :param;
	field $money  :reader :param;
	field $location :reader :writer;
	field $hasBeenOpened=0;
	field $highlighted=0;
	field $picked=0;

=head3 draw()
draws the Box at its location if it has not been opened.  It may be highlighted
when "blink" is added to its decorations.
=cut		

	method draw(){
		return if $hasBeenOpened;
		my $label=$painter->decorate("black,on_white")." ".$number.(" "x(3-length ($number))).$painter->decorate("white,on_red");
		my $decorations=$highlighted?"white,on_red,blink":"white,on_red";
		$painter->printAt($location->{row},$location->{column},
		                  $painter->paint(
                            "┌──────┐\n".
                            "│ $label │\n".
                            "└──────┘",$decorations));
	}
}


=head2 Box
A Banker object interacts with the user
=cut

class Banker{
	field $remarks;
	field $swapOffered;
	method makeOffer($board){
		
	}
	method ringPhone(){
		
	}
}

=head2 Player

A Player object chooses boxes, and when offered is made decides whether to 
take the deal or not.

=cut

class Player{

}

=head2 Painter
A Painter object, draws and decorates items on a terminal window.
=cut

class Painter{
	field %colours=(black   =>30,red   =>31,green   =>32,yellow   =>33,blue   =>34,magenta   =>35,cyan  =>36,white   =>37,
               on_black=>40,on_red=>41,on_green=>42,on_yellow=>43,on_blue=>44,on_magenta=>45,on_cyan=>46,on_white=>47,
               reset=>0, bold=>1, italic=>3, underline=>4, blink=>5, strikethrough=>9, invert=>7,);

=head3 style($style)
returns the Escape sequence that corresponds to an ANSI style
=cut		
    method style($style){
		return exists $colours{$style}?"\033[$colours{$style}m":"";
	}
	
=head3 decorate()
allows multiple style sequences.  these style formats may be passes either as
a comma separted string or an ArrayRef
=cut		
	method decorate($formats){
		my @fmts=ref $formats? @$formats :  split(",",$formats);
		my $dec="";
		foreach (@fmts){
			$dec.=exists $colours{$_}?"\033[$colours{$_}m":"";
		}
		return $dec
	}
	
=head3 paint($string,@formats)
	# multiple styles can used by either using a ref to a list of styles, or comma separated list
	# multiline strings is handled by either using a ref to a list of strings, or comma separated list
=cut
    method paint($string,$formats){ 
		my @strs=ref $string ? @$string  :  split("\n",$string);
		foreach (0..$#strs){
			$strs[$_]=$self->decorate($formats).$strs[$_]."\033[".$colours{"reset"}."m";
		}
		return ref $string?\@strs:join("\n",@strs);
	}
	
=head3 printAt($row,$column,$string)
 print a string to a cursor position
 multiline strings is handled by either using a ref to a list of strings, or comma separated list
=cut	
	method printAt($row,$column,$string){
		my @strs=ref $string ? @$string  :  split("\n",$string);
		print "\033[H\033[".$row++.";$column"."H".$_ foreach (@strs);
	}
}

=head2 Interact
An Interaction Object handles interactions with the Terminal

=cut


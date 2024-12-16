=head1 Deal Or No Deal

=begin html
<img src="https://github.com/saiftynet/DealOrNoDeal/blob/main/Screenshots/Version001.png">
=end html

=cut

use strict;
use warnings;
use Object::Pad;
use lib "lib";
use Game::Term::Interaction;
my $VERSION=0.003;

our $painter=Display->new();
our $ui=new UI;
setupUI();

my $board=Board->new();
my $banker=Banker->new();
$board->run();

=head2 BOARD
A Board object contains all the Box objects which contain Money objects
it's main purpose is to handle the user interface that diplays available
boxes and money left.

=cut

class Board {
   use List::Util qw/shuffle any/;
   field $width :param=80;
   field $height :param=20;
   field $debug :param//=0;
   field @boxes :reader;
   field $playersBox;
   field $gameState :reader :writer ={
	   moneyRevealed=>[], # money revealed in the order they were revealed
	   left=>{},
	   deal=>undef,       # response to offer
	   dealt=>undef,      # deal made
	   endGame=>undef,
	   mode=>"boxPicking",
   };
   field @bankOffers=(22,19,16,13,10,7,4,3,2);
   field $selectedBox=0;
   field $textImage={
	   "deal"=>"██▙ ▄▄▄▖▗▄▄ ▄   
█ ▜▌█▀▀▘█▀▜▌█   
█ ▟▌█▀▘ ███▌█   
██▛ ███▌█ ▐▌███▌",
       "or"=>" ▄▖ ▄▄▄     
▟▛█▖█▀▜▌
█▖▟▌██▛   
▝█▛ █▝█▖ ",
       "nodeal"=>"█▖▐▌ ▄▖   ██▙ ▄▄▄▖▗▄▄ ▄   
██▟▌▟▛█▖  █ ▜▌█▀▀▘█▀▜▌█   ⠀
█▝█▌█▖▟▌  █ ▟▌█▀▘ ███▌█   ⠀
█ ▐▌▝█▛   ██▛ ███▌█ ▐▌███▌",
   };
   
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
	  };
	  @boxes=shuffle(@boxes);
	  foreach (0..$#boxes){
		 $boxes[$_]->set_location({row=>$row,column=>$column});
		 $column+=9;
		 if ($column>($width-20)){
			 $column=15;
			 $row+=4;
	     }
	 }
	}
=head3 draw()
draws the Board.  Simply loops through all the boxes and their contents
and draws them if they are available, then puts the cursor at the bottom of the screen
=cut	  
	  method draw(){
		  foreach (@boxes){
			 $_->draw();
			 $_->money->draw(); 
		 };	
		 $playersBox->draw() if $playersBox;
	  }

=head 3 run()
This prints a splash logo and then starts the UI in Box Micking mode
=cut
	  
	  method run(){
		  $painter->flash($painter->paint($textImage->{deal},"green"),18,15,.2,9);
		  $painter->flash($painter->paint($textImage->{or},"yellow"),18,31,.2,3);
		  $painter->flash($painter->paint($textImage->{nodeal},"red"),18,39,.2,9);
		  $self->draw();
		  $self->message("Host: Welcome to DEAL   OR   NO DEAL!\nPick any box you like\n(Use left and right arrow keys)");
		  $ui->run("boxPicking");
	  }
	  
	  method message($message){
		  $painter->printAt(17,15,[(" " x 52)x7]);  # clear message area
		  $painter->printAt(18,20,$message);        # prints message
	  }
	  
	  method mode($newMode){
		  if ($newMode){
			  $gameState->{mode}=$newMode if $newMode;
			  $ui->stop();
		      $ui->run($newMode);
		  }
		  return $gameState->{mode};
	  }
	  
	  method chooseDoND($dond){
		$gameState->{deal}=$dond;
		my $dColor=$dond  eq "Deal"    ? "green":"yellow";
		my $ndColor=$dond eq "No Deal" ? "red"  :"yellow";
	  	$painter->printAt(19,15,$painter->paint($textImage->{deal},$dColor));
		$painter->printAt(19,31,$painter->paint($textImage->{or},"yellow"));
		$painter->printAt(19,41,$painter->paint($textImage->{nodeal},$ndColor));
	  }
	  
	  method selectDoND(){
			  if ($gameState->{dealt}){
				  $self->message("OK you have already dealt at  £$gameState->{dealt}\n".
				  "Banker would have offered you ".$banker->offer());
			  }
			  else{
				  if ($gameState->{deal} eq "Deal"){
					  $gameState->{dealt}=$banker->offer();
					  $self->message("OK you have dealt at  £$gameState->{dealt}");
				  }
				  else{
					  $self->message("OK you have declined £".$banker->offer());
				  }
			  }	
			  sleep 1;
			  $self->promptOpenBox();
	 }
	  

	  
=head3 chooseBox()
    Choose next box in either direction skipping over player's box 
    wrapping around if needed
=cut	  
	  
	  method chooseBox($delta){
		  if (defined $selectedBox){
			  $selectedBox+=$delta;
			  $selectedBox = 0      if ($selectedBox >= @boxes);
			  $selectedBox =$#boxes if ($selectedBox < 0);
			  $selectedBox+=$delta  if $boxes[$selectedBox]->picked();
			  $selectedBox = 0      if ($selectedBox >= @boxes);
			  $selectedBox =$#boxes if ($selectedBox < 0);
		  }
		  else{ 
			  $selectedBox =0;
		  };		  
		  $self->draw();
	  }
	  
	  method selectedBoxNo(){
		  return 0 unless defined $selectedBox;
		  return $boxes[$selectedBox]->number();
	  }
	  
	  method selectBox(){
		  die unless @boxes;
			  if (not defined $playersBox){
			     $self->message("You have Picked Box Number ".$boxes[$selectedBox]->number()."\nGood Luck!!!\n\nBanker do you want to make an offer?");
			     $self->playerPick();
		         $boxes[$selectedBox]->draw();	
		      }
		      else{				  
		         $self->removeSelected(); 
		         $self->draw();
			  }
		      sleep 1;
		      if (any { $_ == scalar @boxes } @bankOffers ){
				  $self->mode("banker");
				  $banker->makeOffer();
			  }
			  elsif(scalar @boxes==1){
				  $self->finalBox();				  
			  }
			  else{
				   $self->promptOpenBox();
			   }
	  }
	  
	  method finalBox(){
		  
		  $self->message("Ok the final box is left!\n".
		  (($gameState->{dealt})?(" You have already accepted  ".$gameState->{dealt}):
		                          (" You have already rejected  ".$banker->maxOffer())).
		   "\nYour box contained ... ". $playersBox->money()->toString("£"));
		  
	  }

      method promptOpenBox(){
		  $self->message("Use Left and Right Arrow keys\nto choose box to open");
		  $self->mode("boxPicking");
	  }

	  method removeSelected(){
		  my $selBox=$boxes[$selectedBox];
		  $boxes[$selectedBox]->money()->undraw();
		  $boxes[$selectedBox]->undraw();
		  @boxes=(@boxes[0..$selectedBox-1],@boxes[$selectedBox+1..$#boxes]);
		  $self->chooseBox(1); # skip over player's box and blank boxes
		  return $selBox;
	  }
	  
	  method playerPick(){
		  $playersBox=$boxes[$selectedBox];
		  $boxes[$selectedBox]->set_picked(1);
		  $self->chooseBox(1); # skip over player's box and blank boxes
	  }
}

=head2 Money
A Money object is inserted into each Box and is displayed.  Initilly it is 
$avaialble, but as boxes are opened, the value is removed  and not drawn. 
=cut

class Money {
	field $value   :reader :param;
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
		my $label =	(($value<100)  ?((length $value)%2?"":" "):((length $value)%2?" ":"")).
		                            $self->toString("£");
		my $colour=$value<100000?"blue":"magenta";
		my @decs=($painter->decorate($colour),
			       $painter->decorate("white,on_$colour"),
			       $painter->decorate("reset,$colour,on_black"),
			       $painter->decorate("reset"));
		my $padding=" "x((9-length $label)/2);
		$label="$decs[0]◀ ".$decs[1].$padding.$label.$padding."$decs[2]▌▶ $decs[3]";
		$painter->printAt($row*2,($side eq "left"?2:68),$label);
	}
	
	method toString($currencySymbol){
		($value<100)  ? $value.'p':$currencySymbol.($value/100);
	}
	
	method undraw(){
		my $colour=$value<100000?"white,on_blue":"white,on_magenta";
		my $str=$painter->paint($painter->largeNum($self->toString("L")),$colour);
		$board->message("That box contained");
		sleep 1;
		$board->message("");
		$painter->flash($str,19,25,.2,6);
		$painter->printAt($row*2,($side eq "left"?2:68)," "x12);
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
	field $highlighted :reader :writer;
	field $picked :reader :writer;
=head3 draw()
draws the Box at its location if it has not been opened.  It may be highlighted
when "blink" is added to its decorations.
=cut		

	method draw(){
		my $colour=$picked?"green":"red";
		my $label=$painter->decorate("black,on_white")." ".$number.(" "x(3-length ($number))).$painter->decorate("white,on_$colour");
		my $decorations   =$board->selectedBoxNo()?"white,on_$colour":"white,on_$colour,faint";
		my $image=$number!=$board->selectedBoxNo()?
		          "┌──────┐\n│ $label │\n└──────┘":
		          "╔══════╗\n║ $label ║\n╚══════╝";
		$painter->printAt($location->{row},$location->{column},
		                  $painter->paint($image,$decorations));
	}
	
	method undraw(){
		$painter->printAt($location->{row},$location->{column},
		                  $painter->paint([(" "x15)x3],"white,on_black"));
	}
}


=head2 Box
A Banker object interacts with the user
=cut

class Banker{
	field $remarks;
	field $offers=[];
	field $offer :reader;
	field $maxOffer :reader=0;
	field $swapOffered;
	field $already
	
	method makeOffer(){
		$offer=$self->stats();
		$offers=[@$offers,$offer];
		$board->message("With this board,  Banker ". 
		      (($board->gameState()->{dealt})?" would have offered ": "offers you").":");
		$painter->printAt(20,25,$painter->paint($painter->largeNum("L".$offer),"yellow,on_green"));
		sleep 2;
		if ($board->gameState()->{dealt}){
			$board->promptOpenBox();
		}
		else{
			$board->message("Banker offers £$offer... Deal or No Deal?\n(use left right arrow keys, then Enter)?");
			$board->chooseDoND(0);
			$board->mode("dealornodeal");
		}
		
	}
	method ringPhone(){
		
	}
	
	method stats(){
		my @moneyLeft=sort {$a->value()<=>$b->value()} map {$_->money()} $board->boxes();
		my $max=$moneyLeft[-1]->toString("£");
		my $min=$moneyLeft[0]->toString("£");
		my $blues=scalar map {$_->value()>75000?():$_} @moneyLeft;
		my $reds =scalar @moneyLeft-$blues;
		my $offer=$moneyLeft[int ((scalar @moneyLeft)/2)]->value()/100;
		$board->message("There are $blues blues and $reds reds left\n".
		               "You could have $max,\nbut just as likely have $min\n".
		               "With this board\n (and because I like you)");
		sleep 5;
		$maxOffer=$offer if $offer>$maxOffer;
		return $offer;
		
	}
}

sub setupUI(){  # setup the UI
  $ui->setup({
	 default=>{
	 },
     boxPicking=>{
        'rightarrow'=>sub{$board->chooseBox(1)},  # select next box
        'leftarrow' =>sub{$board->chooseBox(-1)}, # previous box 
        'return'    =>sub{$board->selectBox()},
        "updateAction"=>sub{$board->draw();},      
     },
     dealornodeal=>{
        'rightarrow'=>sub{$board->chooseDoND("No Deal")},  # select next box
        'leftarrow' =>sub{$board->chooseDoND("Deal")},  # turn left 
        'return'    =>sub{$board->selectDoND()},
        "updateAction"=>sub{$board->draw();},     
		},
    });

}

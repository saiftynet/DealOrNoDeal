=head1 Deal Or No Deal

=begin html
<img src="https://github.com/saiftynet/DealOrNoDeal/blob/main/Screenshots/Version001.png">
=end html

=cut

use strict;
use warnings;
use Object::Pad;

my $VERSION=0.002;

our $painter=Display->new();
our $ui=new UI;
setupUI($ui);

my $board=Board->new();
$board->draw();
$ui->run("default");

=head2 BOARD
A Board object contains all the Box objects which contain Money objects
it's main purpose is to handle the user interface that diplays available
boxes and money left.

=cut

class Board {
   use List::Util qw/shuffle/;
   field $width :param=80;
   field $height :param=20;
   field $debug :param//=0;
   field @boxes;
   field $playersBox;
   field $selectedBox=0;
   field $removed={};
   field %boxes;           
   field @screen;
   field $mode="boxSelect";
   
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
and draws them if they are available, then pouts the cursor at the bottom of the screen
=cut	  
	  method draw(){
		  foreach (@boxes){
			 $_->draw();
			 $_->money->draw(); 
		 };	
		 $painter->printAt(24,20,$painter->paint($self->debugInfo(),"reset"));
	  }
	  
	  method debugInfo(){
		  return "Selected Box is ".$boxes[$selectedBox]->number(). " ".scalar @boxes." boxes left  \n";	  
	  }
	  
	  method toBox($delta){
		  if (defined $selectedBox){
			  $selectedBox+=$delta;
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
	  
	  method removeBox(){
		  die unless @boxes;
		  $boxes[$selectedBox]->undraw();		  		
		  @boxes=(@boxes[0..$selectedBox-1],@boxes[$selectedBox+1..$#boxes]);
		  $selectedBox = $#boxes if ($selectedBox>$#boxes);
		  $self->draw();
		  
	  }
	  
	  method playerPick(){
		  $playersBox=$boxes[$selectedBox];
		  $self->removeBox()
	  }
	  
	  method openBox(){
		  
		  
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
		$painter->flash($str,19,20,.2,5);
		$painter->printAt($row*2,($side eq "left"?2:68),"            ");
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
	field $picked=0;
=head3 draw()
draws the Box at its location if it has not been opened.  It may be highlighted
when "blink" is added to its decorations.
=cut		

	method draw(){
		my $label=$painter->decorate("black,on_white")." ".$number.(" "x(3-length ($number))).$painter->decorate("white,on_red");
		my $decorations   =$board->selectedBoxNo()?"white,on_red":"white,on_red,faint";
		my $image=$number!=$board->selectedBoxNo()?
		          "┌──────┐\n│ $label │\n└──────┘":
		          "╔══════╗\n║ $label ║\n╚══════╝";
		$painter->printAt($location->{row},$location->{column},
		                  $painter->paint($image,$decorations));
	}
	
	method undraw(){
		$money->undraw();
		$painter->printAt($location->{row},$location->{column},
		                  $painter->paint(
                            "               \n".
                            "               \n".
                            "               ","white,on_black"));
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

=head2 Display
A Display object, draws and decorates items on a terminal window.
=cut

class Display{
	use Time::HiRes "sleep";
	field %colours=(black   =>30,red   =>31,green   =>32,yellow   =>33,blue   =>34,magenta   =>35,cyan  =>36,white   =>37,
               on_black=>40,on_red=>41,on_green=>42,on_yellow=>43,on_blue=>44,on_magenta=>45,on_cyan=>46,on_white=>47,
               reset=>0, bold=>1, faint=>2, italic=>3, underline=>4, blink=>5, strikethrough=>9, invert=>7, fast_blink=>6, no_blink=>25);
    field $buffer="\033[?c";
    field $bigNum={1=>[" ▟ "," ▐ "," ▟▖"],
		           2=>["▞▀▖"," ▞ ","▟▄▖"],
		           3=>["▞▀▖"," ▀▖","▚▄▘"],
		           4=>[" ▟ ","▟▟▖"," ▐ "],
		           5=>["▛▀▘","▀▀▖","▚▄▘"],
		           6=>["▞▀▖","▙▄ ","▚▄▘"],
		           7=>["▀▀▌"," ▞ ","▞  "],
		           8=>["▞▀▖","▞▀▖","▚▄▘"],
		           9=>["▞▀▖","▝▀▌","▚▄▘"],
		           0=>["▞▀▖","▌ ▌","▚▄▘"],
		           " "=>["   ","   ","   "],
		           "L"=>["▗▚ ","▟▄ ","▟▄ "],
		           "p"=>["   ","▗▚ ","▐▘ "],
			   };
     
     BUILD{
		 print "\033[?25l"; # disable blinking cursor
	 }
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
		return unless $string;
		my @strs=ref $string ? @$string  :  split("\n",$string);
		foreach (0..$#strs){
			$strs[$_]=$self->decorate($formats).$strs[$_]."\033[$colours{reset}m";
		}
		return ref $string?\@strs:join("\n",@strs);
	}
	
=head3 printAt($row,$column,$string)
 print a string to a cursor position
 multiline strings is handled by either using a ref to a list of strings, or comma separated list
=cut	
	method printAt($row,$column,$string){
		$string//="";
		my @strs=ref $string ? @$string  :  split("\n",$string);
		print "\033[".$row++.";$column"."H".$_ foreach (@strs);
        $|=1;
	}
	
	method clear(){
		system($^O eq 'MSWin32'?'cls':'clear');
		#print "\033[?25l"; # disable blinking cursor
		$buffer="\033[?c";
	}
	
	method stripColours($str){
        $str=~s/\033\[[^m]+m//g;
        return $str;
	}
	
	method blank($string){
		my @strs=ref $string ? @$string  :  split("\n",$string);
		foreach (0..$#strs){
			$strs[$_]=" " x length($self->stripColours($strs[$_]));
		}
		return ref $string?\@strs:join("\n",@strs);
	}
	
	method flash($string,$row,$column,$interval,$number){
		my $blank=$self->blank($string);
		for (0..$number){
			$self->printAt($row,$column,$string);
			sleep $interval;
			$self->printAt($row,$column,$blank);
		    sleep $interval;
		}
	}
	
	method largeNum($number){
		my $lot=["","",""];
		foreach my $digit  (split //, $number){
			die $digit unless $bigNum->{$digit};
			foreach(0..2){
				$lot->[$_].=$bigNum->{$digit}->[$_]
			}
		}
		return $lot;
	}

}


sub setupUI($ui){  # setup the UI
	    my $keyActions={
        default=>{
            'rightarrow'=>sub{$board->toBox(1)},  # select next box
            'leftarrow' =>sub{$board->toBox(-1)},  # turn left 
            'uparrow'   =>sub{},
            'downarrow' =>sub{},
            'return'    =>sub{$board->removeBox()},
            'd'         =>sub{},
            'a'         =>sub{},
            'pagedown'  =>sub{},
            'pageup'    =>sub{},
            'tab'       =>sub{},
            'shifttab'  =>sub{},
            '#'         =>sub{},
            "updateAction"=>sub{$board->draw();},      
            "windowChange"=>sub{},           
            "m"           =>sub{}, 
        },
    };
	foreach my $k (keys %{$keyActions->{default}}){
            $ui->setKeyAction("default",$k,$keyActions->{"default"}->{$k});
    }
}



=head2 UI
An Interaction Object handles interactions with the Terminal

=cut

class UI{   
#######################################################################################
#####################   User Interaction Object #######################################
#######################################################################################
    field $update=1;
    field $window={width=>80,height=>24};
    field $stty;
    field $mode;
    field $buffer="";
    field $run;
    field $namedKeys={};
    field $actions={};
    field $mapping;
    field $repeat=0;
    field $debug=0;
    
    $SIG{WINCH} = sub {winSizeChange()};
    
    BUILD{
		$namedKeys={
        32     =>  'space',
        13     =>  'return',
        9      =>  'tab',
        '[Zm'  =>  'shifttab',
        '[Am'  =>  'uparrow',
        '[Bm'  =>  'downarrow',
        '[Cm'  =>  'rightarrow',
        '[Dm'  =>  'leftarrow',
        '[Hm'  =>  'home',
        '[2~m' =>  'insert',
        '[3~m' =>  'delete',
        '[Fm'  =>  'end',
        '[5~m' =>  'pageup',
        '[6~m' =>  'pagedown',
        '[Fm'  =>  'end',
        'OPm'  =>  'F1',
        'OQm'  =>  'F2',
        'ORm'  =>  'F3',
        'OSm'  =>  'F4',
        '[15~m'=> 'F5',
        '[17~m'=> 'F6',
        '[18~m'=> 'F7',
        '[19~m'=> 'F8',
        '[21~m'=> 'F10',
        '[24~m'=> 'F12',
    };    
		
	}
    
    method run{
		$mode//="default";
		$run=1;
		$self->get_terminal_size();
		binmode(STDIN);
		$self->ReadMode(5);
		my $key;
		    while ($run) {
				last if ( !$self->dokey($key) );
				$actions->{$mode}->{updateAction}->() // updateAction() if ($update); # update screen
				$update=1;
				$key = $self->ReadKey();
			}
		$self->ReadMode(0);
		print "\n";
	}
    
  method repeat($rep){   # enable or disable keyboard repeat
		$rep//=$repeat?0:1; # if not specified toggle the repeat
		for ($rep){
			/on|1/i && do{
				`xset r on`;
				$repeat=1;
				last;
			};
			/off|0/i && do{
				`xset r off`;
				$repeat=0;
				last;
			};
		}
	}

	method stop{
		$run=0;
		$| = 1;
		`xset r on`;
	}
	
	method dokey($key) {
       return 1 unless (defined $key);
       my $ctrl = ord($key);my $esc="";
       return if ($ctrl == 3);                 # Ctrl+c = exit;
       my $pressed="";
       if ($ctrl==27){
         while ( my $key = $self->ReadKey() ) {
           $esc .= $key;
           last if ( $key =~ /[a-z~]/i );
         }
         if ($esc eq "O"){# F1-F5
            while ( my $key = $self->ReadKey() ) {
             $esc .= $key;
             last if ( $key =~ /[a-z~]/i );
            }
          }    
         $esc.="m"
       };
       if    (exists $namedKeys->{$ctrl}){$pressed=$namedKeys->{$ctrl}}
       elsif (exists $namedKeys->{$esc}) {$pressed=$namedKeys->{$esc}}
       else  {$pressed= ($esc ne "")?$esc:chr($ctrl);};
       $self->act($pressed,$key);    
       return 1;
   }

# if action defined by mode and keypress, then do the action
# otherwise, key press  is entered into buffer
   method act($pressed,$key){ 
      if ($actions->{$mode}->{$pressed}){
        $actions->{$mode}->{$pressed}->();
      }
      else{
        $buffer.=$key;
      } 
    $self->stop() if ($pressed eq "Q");
    print $pressed if $debug;
    $update=1;
  }

  method get_terminal_size {
    if ($^O eq 'MSWin32'){
        `chcp 65001\n`;
        my $geometry=(split("\n", `powershell -command "&{(get-host).ui.rawui.WindowSize;cls}"`))[3];
        ($window->{height}, $window->{width})=(split(/\s+/,$geometry))[1,2];
    }
    else{    
        ($window->{height},  $window->{width} ) = split( /\s+/, `stty size` );
         $window->{height} -= 2;
    }
  }


  method winSizeChange{
    $self->get_terminal_size();
    $actions->{$mode}->{"windowChange"}->() if $actions->{$mode}->{"windowChange"};
  }

  method ReadKey {
    my $key = '';
    sysread( STDIN, $key, 1 );
    return $key;
  }

  method ReadLine { return <STDIN>;}
  
  method ReadMode($mode){
    if ( $mode == 5 ) {  
        $stty = `stty -g`;
        chomp($stty);
        system( 'stty', 'raw', '-echo' );# find Windows equivalent
    }
    elsif ( $mode == 0 ) {
        system( 'stty', $stty ); # find Windows equivalent
    }
  }

### actions to update the screen need to be setup for interactive applications 
  method setKeyAction($mode,$key,$uAction){
    $actions->{$mode}->{$key}=$uAction;
  }

  method updateAction{
    print "\n\r";
   }
}

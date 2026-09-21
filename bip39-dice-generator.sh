#!/bin/bash

export BC_LINE_LENGTH=0

ENTROPY=256 #bits
echo "Selected entropy target: $ENTROPY bits"

# Dice faces, default is 6 => D6
# Note: if you have 2 faces, you are probably flipping a coin :)
dice_faces=6

# The full sequence entered from prompt, contain the resuls achieved by the throws of dices or coins
dice_throws_sequence=''

while getopts "hf:s:" opt; do
	case $opt in
		h) echo "Usage $0 -s sequence [-f faces]";;
    		f) dice_faces=$(echo $OPTARG);;
		s) dice_throws_sequence=$(echo $OPTARG | tr -d ' ');;
  	esac
done

# Convert dice throws sequence in a hash sha256, so it's pointless to get more entropy
sha256value=$(sha256sum <<<$dice_throws_sequence | awk '{print $1}')

# Calculate the number of rolls needed, based on how many faces have the dices
base_entropy=$(echo "l($dice_faces)/l(2)" | bc -l)
needed_number_of_rolls=$(bc -l <<< "$ENTROPY / $base_entropy")

# Round result to units
needed_number_of_rolls=$(awk -v rolls="$needed_number_of_rolls" 'BEGIN { printf "%.0f\n", rolls }')

echo "You have dices with $dice_faces faces"
echo -e "So you have at least to insert $needed_number_of_rolls values to reach the target \n"
echo -e "Inserted sequence of ${#dice_throws_sequence} values: \"$dice_throws_sequence\"\n"

if [ ${#dice_throws_sequence} -lt $needed_number_of_rolls ]; then 
	echo "... but you need at least $needed_number_of_rolls values."	
	exit 1
fi

echo -e "Generated SHA256 from sequence: $sha256value \n"

bin=$(echo -n $sha256value | tr [:lower:] [:upper:] | xargs -I{} sh -c 'echo "obase=2; ibase=16; {}"' | bc)    

if (( ${#bin} % 2 == 1 )); then
    bin="0${bin}"
fi

BINARY_MNEMONICS=$(echo $bin | cut -c 1-$((ENTROPY - 3)))
echo "BINARY MNEMONICS $BINARY_MNEMONICS"

BINARY_MNEMONICS=$(echo $bin | cut -c 1-$((ENTROPY)))

echo ""

LEFTOVERBITS=$(echo $bin | cut -c $((ENTROPY - 2))-$ENTROPY | awk '{print $1}')
echo "LEFT OVER BITS: $LEFTOVERBITS"

echo "SHA256 conversion of the left over bits"
echo $BINARY_MNEMONICS | sha256sum | awk '{print $1}' 

# Convert from HEX (human readable ascii format) to binary data (machine readable)
ENTROPY_BYTES=$(printf '%s' $sha256value | xxd -r -p | sha256sum) #| wc -c

# Get the fist byte from the Sha256 of the entropy (in bytes)
CHECKSUM_BYTE=$(echo -n $ENTROPY_BYTES | cut -c 1-2)

echo $CHECKSUM_BYTE

echo "Convert HEX checksum to binary"
CHECKSUM_BINARY=$(echo -n $CHECKSUM_BYTE | tr [:lower:] [:upper:] | xargs -I{} sh -c 'echo "obase=2; ibase=16; {}"' | bc) 

echo $CHECKSUM_BINARY

finalMnemonics=$BINARY_MNEMONICS$CHECKSUM_BINARY"0"

declare -A finalMatrix
i=0
 while IFS= read -r group; do
	finalMatrix["$i,0"]=$group
	finalMatrix["$i,1"]=$((2#$group+1))
	finalMatrix["$i,2"]=99999
	((i += 1))
done < <(fold -w11 <<< "$finalMnemonics")

echo "${finalMatrix[0,2]}"

echo -e "\nBINARY MNEMONICS, INTEGER CONVERSION, INTEGER MNEMONIC" 
echo -e "$finalMnemonics \n" | fold -w 11

#echo "$BINARY_MNEMONICS$CHECKSUM_BINARY" | fold -w 11 | xargs -I{} sh -c 'echo "obase=10; ibase=2; {}"' | bc 

# Convert binary numbers to decimal numbers + 1 to check the bip39 lookup table
echo "BIP39 numbers"
printf '%s' "$finalMnemonics" |
  fold -w 11 |
  while read -r group; do
    printf '%d\n' "$((2#$group+1))"
  done

echo -e "\n"

printf "%-15s %-10s %-20s\n" "Binary" "Decimal" "Word"
printf "%s\n" "----------------------------------------------"
for i in $(seq 0 23); do
    printf "%-15s %-10s %-20s\n" "${finalMatrix[$i,0]}" "${finalMatrix[$i,1]}" "${finalMatrix[$i,2]}"
done

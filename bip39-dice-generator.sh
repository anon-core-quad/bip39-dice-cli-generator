#!/bin/bash

export BC_LINE_LENGTH=0

ENTROPY=256 #bits

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

printf "%-20s %-10s\n" "Param" "Value"
echo "----------------------------------"
printf "%-20s %-10s\n" "Entropy" "$ENTROPY"
printf "%-20s %-10s\n" "Dice Faces" "$dice_faces"
printf "%-20s %-10s\n" "Necessari throws" "$needed_number_of_rolls"
printf "%-20s %-10s\n" "Inserted throws" "${#dice_throws_sequence}"
echo "----------------------------------"

echo -e "\nInserted sequence:\n$dice_throws_sequence\n"

if [ ${#dice_throws_sequence} -lt $needed_number_of_rolls ]; then 
	echo "ERROR: you need at least $needed_number_of_rolls values."	
	exit 1
fi

echo -e "Generated SHA256 from sequence:\n$sha256value \n"

bin=$(echo -n $sha256value | tr [:lower:] [:upper:] | xargs -I{} sh -c 'echo "obase=2; ibase=16; {}"' | bc)    

if (( ${#bin} % 2 == 1 )); then
    bin="0${bin}"
fi

BINARY_MNEMONICS=$(echo $bin | cut -c 1-$((ENTROPY - 3)))
echo -e "BINARY MNEMONICS:\n$BINARY_MNEMONICS"

BINARY_MNEMONICS=$(echo $bin | cut -c 1-$((ENTROPY)))

echo ""

LEFTOVERBITS=$(echo $bin | cut -c $((ENTROPY - 2))-$ENTROPY | awk '{print $1}')
echo -e "LEFT OVER BITS: $LEFTOVERBITS"

#echo ""
#echo "SHA256 conversion of the left over bits:"
#echo $BINARY_MNEMONICS | sha256sum | awk '{print $1}'

# Convert from HEX (human readable ascii format) to binary data (machine readable) and reconvert in sha256
ENTROPY_BYTES=$(printf '%s' $sha256value | xxd -r -p | sha256sum)

# Get the fist byte from the Sha256 of the entropy (in bytes)
CHECKSUM_BYTE=$(echo -n $ENTROPY_BYTES | cut -c 1-2)

CHECKSUM_BINARY=$(echo -n $CHECKSUM_BYTE | tr [:lower:] [:upper:] | xargs -I{} sh -c 'echo "obase=2; ibase=16; {}"' | bc) 

#echo $CHECKSUM_BYTE
#echo $CHECKSUM_BINARY

echo "CHECKSUM:" $LEFTOVERBITS$CHECKSUM_BINARY

finalMnemonics=$BINARY_MNEMONICS$CHECKSUM_BINARY"0"

# Download official BIP39 word list
wget -o /dev/null -O bip39-english.txt https://raw.githubusercontent.com/bitcoin/bips/refs/heads/master/bip-0039/english.txt 

echo -e "\n"

declare -A bip39words
j=1
while IFS= read -r line; do
	bip39words[$j]=$line
	((j++))
done < bip39-english.txt

# Create a tridimensional array with binary values, integer converted values and the corrispondent bip39 word
declare -A finalMatrix
i=0
while IFS= read -r group; do
	decimalConversion=$((2#$group+1))
	finalMatrix["$i,0"]=$group
	finalMatrix["$i,1"]=$decimalConversion
	finalMatrix["$i,2"]=${bip39words[$decimalConversion]}
	((i += 1))
done < <(fold -w11 <<< "$finalMnemonics")


# Print a table of the results
printf "%-15s %-10s %-20s\n" "Binary" "Decimal" "Word"
printf "%s\n" "----------------------------------------------"
for i in $(seq 0 23); do
    printf "%-15s %-10s %-20s\n" "${finalMatrix[$i,0]}" "${finalMatrix[$i,1]}" "${finalMatrix[$i,2]}"
done

echo ""

# Print inline seed words
echo "===================== SEED WORDS ======================="
for i in $(seq 0 23); do
    printf "%s " "${finalMatrix[$i,2]}"
done
echo -e "\n============================================="

echo ""

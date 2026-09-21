To generate a strong wallet, you need a strong source of entropy. This because the private key is nothing more than a simple number between 2^1 and 2^256.

To be secure against a bruteforce attack you need at least 128 bits of entropy. This is the motivation behind the choice of the minimum entropy in bip39 wallets.

The human race are not good to generate an unbiased source of entropy. Something that it seems random it's the result of our personal experiences mixed with our personal temperament.

You have only two choices to get a random number:
- RNG function from a electronic device, like a PC or hardware wallet
- The vibrations of the universe canalized thought a multiple throws of dices

The former is the fastest and comfortable choice, but you can't be shure that a some point someone finds out a vulnerability in this functions and at our expense we discover that the key you have generated is not much random as you thought.



2^256 1.157920892373162e+77

log(6) / log(2) = log2(6) = 2.584962500721156 ~ 2.585 bits

Roll D6 dice
log2(6) = 2.584962500721156 * 99 = 255.91128757139444 ~ 256 bits

Flip a coin
log2(2) = 1 * 256 = 256 bits

I created this very simple script for myself but I published it in case it might be helful to someone.

Just for testing purpose you can generate a pseudo-random sequence of throws with this command:
shuf -r -i 1-6 -n 99 | tr -d '\n'

DO NOT USE THE GENERATE SEQUENCE FOR REAL WALLET!!
USE PHYSICAL DICES!!!

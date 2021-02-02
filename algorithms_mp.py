import multiprocessing
import itertools

def check_word(word, wordlist):
    return (word, word.upper() in wordlist)

def valid_permutations(word, wordlist):
    perms = []
    for i in range(len(word)+1):
        for j in itertools.permutations(word, i):
            w = "".join(j)
            if check_word(w, wordlist):
                perms.append(w)
    return perms

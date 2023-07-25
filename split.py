import sys, pprint, itertools

# This script searches for the strings below and then links all other
# duplicates to that name.
# That way, we can prefer these names. Some of them have aliases where the
# alias that would be chosen by rdfind (called in build-tzdata.sh) are much
# smaller cities.

def lin(theselines):
    for j in theselines:
        if "Moscow" in j or "Etc/UTC" in j or "Berlin" in j or "London" in j or "Dublin" in j or "Havana" in j or "Santiago" in j or \
           'Tripoli' in j or 'Winnipeg' in j or 'Auckland' in j or 'Edmonton' in j or 'Toronto' in j or 'Vancouver' in j or 'Halifax' in j or \
           'Sydney' in j or 'Denver' in j or 'Jerusalem' in j or 'Tijuana' in j or 'Dar_es_Salaam' in j or 'Bangkok' in j or 'Abidjan' in j or \
           'Riyadh' in j or 'Mexico_City' in j or 'Honolulu' in j or 'Cairo' in j or 'New_York' in j or 'Istanbul' in j:
            # Now that we found the right entry, we iterate from the beginning and link all to this one
            for k in theselines:
                if k != j:
                    print(f"ln --force --symbolic --relative {j} {k}")
            return

lst = sys.stdin.read().split("\n\n")
for i in lst:
    theselines=i.strip().split("\n")
    lin(theselines)


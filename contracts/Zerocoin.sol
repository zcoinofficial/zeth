pragma solidity ^0.4.8;

import "contracts/BigNumberLib.sol";

contract zerocoin { 

    using BigNumberLib for *;
    /*
     * This smart contract is an implementation of the Zerocoin coin-mixing protocol.
     * paper found here: http://zerocoin.org/media/pdf/ZerocoinOakland.pdf
     * original authors: Ian Miers, Christina Garman, Matthew Green, Aviel D. Rubin
     * this version implemented by: Tadhg Riordan - github.com/riordant
     */

     //*************************************** Begin Parameters ********************************************

     /* The parameters are generated based on the 2048 bit value generated for the RSA Factoring Challenge - the same 
      * value used for parameter generation in Zcoin.
      * This can be verified by using the paramgen tool in the libzerocoin lib by building project 
      * @ https://github.com/zcoinofficial/zcoin/tree/master/src/libzerocoin.
      * struct and BigNumberLib.BigNumber values will be generated in this contract's constructor by the Zcoin team.
      */
    address deployment; //address of contract creators. Ability to perform limited changes and for contract deployment. TBD
    bool set = false; //parameters set
 
    int zkp_iterations = 80;

    //accumulator params
    uint k_prime = 160;
    uint k_dprime = 128;


    //the following value is used in the commitment PoK verification and is equal to:
    //64 * (COMMITMENT_EQUALITY_CHALLENGE_SIZE (==256) + COMMITMENT_EQUALITY_SECMARGIN (==512) +
    //      max(max(serial_number_sok_commitment_group.modulus.bit_size(),    accumulator_pok_commitment_group.modulus.bit_size()),
    //      max(serial_number_sok_commitment_group.group_order.bit_size(), accumulator_pok_commitment_group.group_order.bit_size())));
    uint commitment_pok_max_size;

    BigNumberLib.BigNumber commitment_pok_challenge_size; // 2^COMMITMENT_EQUALITY_CHALLENGE_SIZE(==256) - 1

    //greatest and smallest values for coin
    BigNumberLib.BigNumber min_coin_value;
    BigNumberLib.BigNumber max_coin_value;

    bytes challenge_commitment_base; //hash of challenge commitment identification string and parameters


    //for hash function in serial number SoK verification
    BigNumberLib.BigNumber params_bytes;

    //RSA-2048 Factoring Challenge encoded as bytes.
    BigNumberLib.BigNumber modulus; //RSA-2048

    //the following value is used in the accumulator verification and is equal to:
    //maxCoinValue * BigNumberLib.BigNumber(2).pow(k_prime + k_dprime + 1))
    BigNumberLib.BigNumber upper_result_range_value;
    
    _accumulator_pok_commitment_group accumulator_pok_commitment_group;
    _accumulator_qrn_commitment_group accumulator_qrn_commitment_group;
    _coin_commitment_group coin_commitment_group;
    _serial_number_sok_commitment_group serial_number_sok_commitment_group;

    //these structs will be assigned in contract contructor.
    struct _accumulator_pok_commitment_group{
        BigNumberLib.BigNumber g;
        BigNumberLib.BigNumber h;
        BigNumberLib.BigNumber modulus;
        BigNumberLib.BigNumber group_order;
    }

    struct _accumulator_qrn_commitment_group{
        BigNumberLib.BigNumber g;
        BigNumberLib.BigNumber h;
    }

    struct _coin_commitment_group{
        BigNumberLib.BigNumber g;
        BigNumberLib.BigNumber h;
        BigNumberLib.BigNumber modulus;
        BigNumberLib.BigNumber group_order;
    }

    struct _serial_number_sok_commitment_group{
        BigNumberLib.BigNumber g;
        BigNumberLib.BigNumber h;
        BigNumberLib.BigNumber modulus;
        BigNumberLib.BigNumber group_order;
    }
    //*************************************** End Parameters ********************************************


    //*************************************** Begin Values **********************************************

    //add eth value pool here.

    uint accumulator = 961; //initial value for accumulator (accumulatorBase)

    //*************************************** End Values ************************************************


    //*************************************** Begin Persistent Data Structures ********************************
    //both maps and dynamic arrays are used.
    //maps give constant access time where needed, but are not easily iterable, and so we use lists for storage.

    mapping(bytes32 => BigNumberLib.BigNumber) public serial_numbers; //revealed serial numbers, mapped by SHA256 hash
    mapping(bytes32 => BigNumberLib.BigNumber) public commitments; //minted commitments, mapped by SHA256 hash
    mapping(bytes32 => BigNumberLib.BigNumber) public accumulators; //iteratively computed accumulators, mapped by SHA256 hash

    BigNumberLib.BigNumber[] accumulator_list;
    BigNumberLib.BigNumber[] commitment_list; // accumulator_n^ commitment_n = accumulator_n+1
    
    //*************************************** Begin Persistent Data Structures **********************************


    //********************************* Begin Temporary Proof Structures *********************************
    //These data structures exist only in memory, i.e. for the duration of the transaction call.

    // The client initially generates two separate commitments (here, serial_number_commitment and accumulator_commitment) 
    // to the public coin (C), each under a different set of public parameters.
    // the ZK proof takes these values as parameters and verifies that the two commitments contain the same public coin.
    struct _commitment_pok {
        BigNumberLib.BigNumber S1;
        BigNumberLib.BigNumber S2;
        BigNumberLib.BigNumber S3;
        BigNumberLib.BigNumber challenge;
    }

    // Proves that the committed public coin is in the Accumulator (PoK of "witness")
    struct _accumulator_pok {
        BigNumberLib.BigNumber C_e;
        BigNumberLib.BigNumber C_u;
        BigNumberLib.BigNumber C_r;
        BigNumberLib.BigNumber[3] st;
        BigNumberLib.BigNumber[4] t;
        BigNumberLib.BigNumber s_alpha;
        BigNumberLib.BigNumber s_beta;
        BigNumberLib.BigNumber s_zeta;
        BigNumberLib.BigNumber s_sigma;
        BigNumberLib.BigNumber s_eta;
        BigNumberLib.BigNumber s_epsilon;
        BigNumberLib.BigNumber s_delta;
        BigNumberLib.BigNumber s_xi;
        BigNumberLib.BigNumber s_phi;
        BigNumberLib.BigNumber s_gamma;
        BigNumberLib.BigNumber s_psi;
    }

    // Proves that the coin is correct w.r.t. serial number and hidden coin secret
    struct _serial_number_sok {
        BigNumberLib.BigNumber[80] s_notprime;
        BigNumberLib.BigNumber[80] sprime;
        bytes32 hash;
    }

    //********************************* End Temporary Proof Structures *******************************************

    //*************************************** Begin Constructor **************************************************
    function zerocoin(address _in){
        require(!is_set && _in==deployment);
        //add parameters
        //initialize structures
    }
    //***************************************** End Constructor **************************************************

    
    //********************************* Begin 'Mint' validation ****************************************************
    function validate_coin_mint(bytes _commitment) returns (bool success){
        BigNumberLib.BigNumber commitment; //serialize bytes input as struct object here

        assert (cmp(min_coin_value,commitment)==LT) && 
                cmp(commitment, max_coin_value)==LT) && 
                is_prime(commitment) &&
                !(commitments[sha256(commitment)]==commitment));

        //must also check that denomination of eth sent is correct
        
        //add to accumulator. new accumulator = old accumulator ^ serial_number_commitment mod modulus.
        BigNumberLib.BigNumber old_accumulator = accumulator_list[accumulator_list.length-1];
        BigNumberLib.BigNumber accumulator =prepare modexp(old_accumulator, commitment, modulus);
        accumulators[sha256(accumulator)] = accumulator; 
        accumulator_list.push(accumulator); //add to list and map

        commitments[sha256(commitment)]==serial_number_commitment;
        commitment_list.push(commitment); //add to list and map

        // add eth denomination to value pool

        return true;
    }

    function is_prime(BigNumberLib.BigNumber serial_number_commitment) returns (bool){
        //executes Miller-Rabin Primality Test for input.

    }

    //********************************* End 'Mint' validation **********************************************************

    //********************************* Begin 'Spend' verification *****************************************************
    function verify_coin_spend(bytes commitment_pok_in, 
                               bytes accumulator_pok_in, 
                               bytes serial_number_sok_in, 
                               bytes accumulator,
                               bytes coin_serial_number,
                               bytes serial_number_commitment,
                               bytes accumulator_commitment,
                               bytes output_address) returns (bool result) { 

        //serialize bytes inputs as struct objects.

        assert(verify_commitment_pok(commitment_pok, serial_number_commitment, accumulator_commitment) &&
               verify_accumulator_pok(accumulator_pok, accumulator, accumulator_commitment) &&
               verify_serial_number_sok(serial_number_sok, coin_serial_number, serial_number_commitment) &&
               !(   serial_numbers[sha256(coin_serial_number)]==coin_serial_number));
        
        //send denomination of eth from value pool to output_address

        //add coin_serial_number to map of used serial numbers
        serial_numbers[sha256(coin_serial_number)]==coin_serial_number;
        }
    }

    function verify_commitment_pok(_commitment_pok commitment_pok, BigNumberLib.BigNumber serial_number_commitment, BigNumberLib.BigNumber accumulator_commitment) private returns (bool result){
        // Compute the maximum range of S1, S2, S3 and verify that the given values are in a correct range.

        //get bit sizes of each of the arguments.
        uint s1_bit_size = get_bit_size(commitment_pok.S1);
        uint s2_bit_size = get_bit_size(commitment_pok.S2);
        uint s3_bit_size = get_bit_size(commitment_pok.S3); 

        assert(s1_bit_size < commitment_pok_max_size &&
               s2_bit_size < commitment_pok_max_size &&
               s3_bit_size < commitment_pok_max_size &&
               (cmp(challenge, challenge_size) == LT)); 
            

        // Compute T1 = g1^S1 * h1^S2 * inverse(A^{challenge}) mod p1
        BigNumberLib.BigNumber T1 = prepare_modexp(serial_number_commitment, challenge, serial_number_sok_commitment_group.modulus);
        T1 = inverse(T1, serial_number_sok_commitment_group.modulus);
        T1 = modmul(T1, 
                    modmul(prepare_modexp(serial_number_sok_commitment_group.g, S1, serial_number_sok_commitment_group.modulus), prepare_modexp(serial_number_sok_commitment_group.h, S2, serial_number_sok_commitment_group.modulus), serial_number_sok_commitment_group.modulus),
                    serial_number_sok_commitment_group.modulus);

        // Compute T2 = g2^S1 * h2^S3 * inverse(B^{challenge}) mod p2
        BigNumberLib.BigNumber T2 = prepare_modexp(accumulator_commitment, challenge, accumulator_pok_commitment_group.modulus);
        T2 = inverse(T2, accumulator_pok_commitment_group.modulus);
        T2 = modmul(T2,
                    modmul(prepare_modexp( accumulator_pok_commitment_group.g, S1,  accumulator_pok_commitment_group.modulus), prepare_modexp( accumulator_pok_commitment_group.h, S3,  accumulator_pok_commitment_group.modulus),  accumulator_pok_commitment_group.modulus),
                    accumulator_pok_commitment_group.modulus);

        // Hash T1 and T2 along with all of the public parameters
        Bignum computed_challenge = calculate_challenge_commitment_pok(serial_number_commitment, accumulator_commitment, T1, T2);

        // Return success if the computed challenge matches the incoming challenge
        if(computed_challenge == commitment_pok.challenge) return true;

        // Otherwise return failure
        return false;


    }

    function bitcoin_sha256(string in_data) public returns (bytes32){
        //bitcoin hashes inputs twice.
        //we also hash strings including the length byte (the client hashes strings using std::string from c++, which precedes the string with the length).
        //this may change if we decide to use keccak on the client-side, which we probably will if security is the same.
        bytes memory w;
        
        uint in_length = in_data.length;

         assembly{
             let m_alloc := msize()
             w := m_alloc
             let byte_length := add(mload(in_data),1)
             mstore(m_alloc, byte_length) // store length in memory
             calldatacopy(add(m_alloc,0x20), 0x43, byte_length)
             mstore(0x40,add(m_alloc, add(0x20, div(mload(in_data),0x20)  )) )
        }
        
        return sha256(sha256(w));
    }

    function calculate_challenge_commitment_pok(BigNumberLib.BigNumber serial_number_commitment, BigNumberLib.BigNumber accumulator_commitment, BigNumberLib.BigNumber T1, BigNumberLib.BigNumber T2) returns (bytes32){
        /* Hash together the following elements:
         * -proof identifier
         * -Commitment A
         * -Commitment B
         * -Ephemeral commitment T1
         * -Ephemeral commitment T2
         * -commitment A parameters
         * -commitment B parameters
         * all representented as bytes.
         * the byte object identifying the proof and parameters is constant and therefore pre created.
         */

         bytes hasher = challenge_commitment_base;
         //TBD: Assembly implementation

         return sha256(hasher);
    }

    function calculate_challenge_serial_number_pok(BigNumberLib.BigNumber a_exp, BigNumberLib.BigNumber b_exp, BigNumberLib.BigNumber h_exp) private returns (BigNumberLib.BigNumber){
        BigNumberLib.BigNumber a = coin_commitment_group.g;
        BigNumberLib.BigNumber b = coin_commitment_group.h;
        BigNumberLib.BigNumber g = serial_number_sok_commitment_group.g;
        BigNumberLib.BigNumber h = serial_number_sok_commitment_group.h;


        //both of these operations are modmuls.
        BigNumberLib.BigNumber exponent = modmul(prepare_modexp(a, a_exp, serial_number_sok_commitment_group.group_order), prepare_modexp(b, b_exp, serial_number_sok_commitment_group.group_order), serial_number_sok_commitment_group.group_order);

        return modmul(prepare_modexp(g, exponent, serial_number_sok_commitment_group.modulus), prepare_modexp(h, h_exp, serial_number_sok_commitment_group.modulus), serial_number_sok_commitment_group.modulus);   
    }

    function verify_serial_number_sok(_serial_number_sok serial_number_sok, BigNumberLib.BigNumber coin_serial_number, BigNumberLib.BigNumber serial_number_commitment) private returns (bool result){

        //initially verify that coin_serial_number has not already been used. mapping gives O(1) access
        if((serial_numbers[sha256(coin_serial_number)] == coin_serial_number)) throw;
        
        BigNumberLib.BigNumber a = coin_commitment_group.g;
        BigNumberLib.BigNumber b = coin_commitment_group.h;
        BigNumberLib.BigNumber g = serial_number_sok_commitment_group.g;
        BigNumberLib.BigNumber h = serial_number_sok_commitment_group.h;

        bytes hasher;
        //hasher << *params << valueOfCommitmentToCoin <<coinSerialNumber;
        //hash the above into hasher

        BigNumberLib.BigNumber[zkp_iterations] tprime;

        for(uint i = 0; i < zkp_iterations; i++) {
            uint bit = i % 8;
            uint byte = i / 8;
            uint challenge_bit = ((serial_number_sok.hash[byte] >> bit) & 0x01);
            if(challenge_bit == 1) {
                tprime[i] = calculate_challenge_serial_number_pok(coin_serial_number, serial_number_sok.s_notprime[i], serial_number_sok.sprime[i]);
            } else {
                Bignum exp = prepare_modexp(b, serial_number_sok.s_notprime[i], serial_number_sok_commitment_group.group_order);
                tprime[i] = modmul(prepare_modexp(prepare_modexp(serial_number_commitment, exp, serial_number_sok_commitment_group.modulus), 1, serial_number_sok_commitment_group.modulus),
                                    prepare_modexp(prepare_modexp(h, serial_number_sok.sprime[i], serial_number_sok_commitment_group.modulus), 1, serial_number_sok_commitment_group.modulus),
                                    serial_number_sok_commitment_group.modulus);
            }
        }
        for(uint i = 0; i < zkp_iterations; i++) {
            hasher.push(tprime[i]);
        }
        return (sha256(hasher) == serial_number_sok.hash);
        
        }
    
    // Verifies that a commitment c is accumulated in accumulator a
    function verify_accumulator_pok(_accumulator_pok accumulator_pok, BigNumberLib.BigNumber accumulator, BigNumberLib.BigNumber accumulator_commitment) private returns (bool){

        //initially verify that accumulator exists. mapping gives O(1) access
        if(!(accumulators[sha256(accumulator)] == accumulator)) throw;

        BigNumberLib.BigNumber sg = accumulator_pok_commitment_group.g;
        BigNumberLib.BigNumber sh = accumulator_pok_commitment_group.h;

        BigNumberLib.BigNumber g_n = accumulator_qrn_commitment_group.g;
        BigNumberLib.BigNumber h_n = accumulator_qrn_commitment_group.h;

        bytes hasher;
        //hasher << *params << sg << sh << g_n << h_n << accumulator_commitment << accumulator_pok.C_e << accumulator_pok.C_u << accumulator_pok.C_r << accumulator_pok.st[0] << accumulator_pok.st[1] << accumulator_pok.st[2] << accumulator_pok.t[0] << accumulator_pok.t[1] << accumulator_pok.t[2] << accumulator_pok.t[3];
        //hash together inputs above
        BigNumberLib.BigNumber c = BigNumberLib.BigNumber(hasher); //this hash should be of length k_prime bits

        BigNumberLib.BigNumber[3] st_prime;
        BigNumberLib.BigNumber[4] t_prime;

        BigNumberLib.BigNumber A,B,C;

        A = prepare_modexp(accumulator_commitment, c, accumulator_pok_commitment_group.modulus);
        B = prepare_modexp(sg, accumulator_pok.s_alpha, accumulator_pok_commitment_group.modulus);
        C = prepare_modexp(sh, accumulator_pok.s_phi, accumulator_pok_commitment_group.modulus);
        st_prime[0] = prepare_modexp(mul(mul(A,B),C), 1, accumulator_pok_commitment_group.modulus;                        

        A = prepare_modexp(sg, c, accumulator_pok_commitment_group.modulus);
        B = prepare_modexp(mul(accumulator_commitment,inverse(sg,accumulator_pok_commitment_group.modulus)), accumulator_pok.s_gamma, accumulator_pok_commitment_group.modulus);
        C = prepare_modexp(sh, accumulator_pok.s_psi, accumulator_pok_commitment_group.modulus);
        st_prime[1] = prepare_modexp(mul(mul(A,B),C), 1, accumulator_pok_commitment_group.modulus;                        

        A = prepare_modexp(sg, c, accumulator_pok_commitment_group.modulus);
        B = prepare_modexp(mul(sg,accumulator_commitment),accumulator_pok.s_sigma, accumulator_pok_commitment_group.modulus);
        C = prepare_modexp(sh, accumulator_pok.s_xi, accumulator_pok_commitment_group.modulus);
        st_prime[2] = prepare_modexp(mul(mul(A,B),C), 1, accumulator_pok_commitment_group.modulus; 


        A = prepare_modexp(accumulator_pok.C_r, c, modulus);
        B = prepare_modexp(h_n, accumulator_pok.s_zeta, modulus);
        C = prepare_modexp(g_n, accumulator_pok.s_epsilon, modulus);
        t_prime[0] = prepare_modexp(mul(mul(A,B),C), 1, modulus; 

        A = prepare_modexp(accumulator_pok.C_e, c, modulus);
        B = prepare_modexp(h_n, accumulator_pok.s_eta, modulus);
        C = prepare_modexp(g_n, accumulator_pok.s_alpha, modulus);
        t_prime[1] = prepare_modexp(mul(mul(A,B),C), 1, modulus; 

        A = prepare_modexp(accumulator, c, modulus);
        B = prepare_modexp(accumulator_pok.C_u, accumulator_pok.s_alpha, modulus);
        C = prepare_modexp(inverse(h_n, modulus), accumulator_pok.s_beta, modulus);
        t_prime[2] = prepare_modexp(mul(mul(A,B),C), 1, modulus;

        A = prepare_modexp(accumulator_pok.C_r, accumulator_pok.s_alpha, modulus);
        B = prepare_modexp(inverse(h_n,modulus),accumulator_pok.s_delta, modulus);
        C = prepare_modexp(inverse(g_n, modulus),accumulator_pok.s_beta, modulus);
        t_prime[3] = prepare_modexp(mul(mul(A,B),C), 1, modulus; 

        bool[3] result_st;
        bool[4] result_t;

        bool result_st[0] = (st[0] == st_prime[0]);
        bool result_st[1] = (st[1] == st_prime[1]);
        bool result_st[2] = (st[2] == st_prime[2]);

        bool result_t[0] = (t[0] == t_prime[0]);
        bool result_t[1] = (t[1] == t_prime[1]);
        bool result_t[2] = (t[2] == t_prime[2]);
        bool result_t[3] = (t[3] == t_prime[3]);

        //(maxCoinValue * BigNumberLib.BigNumber(2).pow(k_prime + k_dprime + 1))) in params as upper_result_range_value
        BigNumberLib.BigNumber lower_result_range_value = upper_result_range_value;
        lower_result_range_value.neg = 1;
        bool result_range = (cmp(accumulator_pok.s_alpha, result_range_value) == LT) && (cmp(accumulator_pok.s_alpha, result_range_value) == GT);

        return (result_st[0] && result_st[1] && result_st[2] && result_t[0] && result_t[1] && result_t[2] && result_t[3] && result_range);   
    }
    //********************************* End 'Spend' verification *****************************************************
}
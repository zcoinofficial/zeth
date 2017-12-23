// Specifically request an abstraction for BigNumber
var MockBigNumberLib = artifacts.require("MockBigNumberLib"); 

var bn = require('bn.js')
var crypto = require("crypto")  

contract('MockBigNumberLib', function(accounts) {
  init_runs = 100; 
  for(var run=init_runs;run>0;run--){
  it("Modexp function: Run " + (init_runs-run) + " - create random inputs for A and B, sub to get C, assert equality from contract", async function() {
        instance = await MockBigNumberLib.new()
        var a_size = (Math.floor(Math.random() * 6) + 1) * 32
        var a_val = crypto.randomBytes(a_size).toString('hex');
        var b_size = (Math.floor(Math.random() * 6) + 1) * 32
        var b_val = crypto.randomBytes(b_size).toString('hex'); 
        var mod_size = (Math.floor(Math.random() * 6) + 1) * 32
        var mod_val = crypto.randomBytes(mod_size).toString('hex'); //create random hex strings up to 2048 bit sizes. size of values generated are smaller - out of gas otherwise (will have to deal with this - maybe set a limit on input?)

        // var a_neg = Math.random() >= 0.5;
        // var b_neg = Math.random() >= 0.5; //generates a random boolean.
        // var mod_neg = Math.random() >= 0.5; //generates a random boolean.

        var a_neg = false;
        var b_neg = false;
        var mod_neg = false; //all positive for now - need to implement inverse function to deal with negative exponent.

        var a_bn = new bn((a_neg ? "-" : "") + a_val, 16);
        var b_bn = new bn((b_neg ? "-" : "") + b_val, 16);
        var mod_bn = new bn((mod_neg ? "-" : "") + mod_val, 16);
        
        var res_bn = a_bn.toRed(bn.red(mod_bn)).redPow(b_bn).fromRed(); //calculates modexp.

        expected_result_val = res_bn.toString('hex')
        if(expected_result_val[0] == '-'){
          expected_result_neg = true;
          expected_result_val = expected_result_val.substr(1)
        }else expected_result_neg = false;
      
        var a_msb = a_bn.bitLength()
        var a_msb_enc = "0".repeat(64 - a_bn.bitLength().toString(16).length) + a_bn.bitLength().toString(16)

        var b_msb = b_bn.bitLength()
        var b_msb_enc = "0".repeat(64 - b_bn.bitLength().toString(16).length) + b_bn.bitLength().toString(16)

        var mod_msb = mod_bn.bitLength()
        var mod_msb_enc = "0".repeat(64 - mod_bn.bitLength().toString(16).length) + mod_bn.bitLength().toString(16)

        var   a_val_enc = "0x" +   a_val
        var   b_val_enc = "0x" +   b_val
        var mod_val_enc = "0x" + mod_val

        var   a_extra_enc = "0x" + "0".repeat(63) + ((  a_neg==true) ? "1" : "0") +   a_msb_enc;
        var   b_extra_enc = "0x" + "0".repeat(63) + ((  b_neg==true) ? "1" : "0") +   b_msb_enc;
        var mod_extra_enc = "0x" + "0".repeat(63) + ((mod_neg==true) ? "1" : "0") + mod_msb_enc;

        
        expected_result_val = "0x" + ((expected_result_val.length  % 64 != 0) ? "0".repeat(64 - (expected_result_val.length % 64)) : "") + expected_result_val //add any leading zeroes (not present from BN)
        var expected_result_msb = res_bn.bitLength()
                   
      instance.mock_modexp.call(a_val_enc, a_extra_enc, b_val_enc, b_extra_enc, mod_val_enc, mod_extra_enc).then(function(actual_result) {
        assert.equal(expected_result_val, actual_result[0], "returned val did not match. \na_val:\n" + a_val + "\nb_val:\n" + b_val + "\nmod_val:\n" + mod_val + "\na_msb:\n" + a_msb_enc + "\nb_msb:\n" + b_msb_enc + "\nmod_msb:\n" + mod_msb_enc + "\na_neg:\n" + a_neg + "\nb_neg:\n" + b_neg + "\nmod_neg:\n" + mod_neg + "\n");
        assert.equal(expected_result_neg, actual_result[1], "returned neg did not match. \na_val:\n" + a_val + "\nb_val:\n" + b_val + "\na_msb:\n" + a_msb_enc + "\nb_msb:\n" + b_msb_enc + "\n" + "\na_neg:\n" + a_neg + "\nb_neg:\n" + b_neg + "\n");
        assert.equal(expected_result_msb, actual_result[2].valueOf(), "returned msb did not match. \nresult: " + expected_result_val + "\na_val:\n" + a_val + "\nb_val:\n" + b_val + "\nmod_val:\n" + b_val + "\na_msb:\n" + a_msb_enc + "\nb_msb:\n" + b_msb_enc + "\n" + "\na_neg:\n" + a_neg + "\nb_neg:\n" + b_neg + "\n");
      })
  });
  
  it("Multiplication function: Run " + (init_runs-run) + " - create random inputs for A and B, sub to get C, assert equality from contract", async function() {
        instance = await MockBigNumberLib.new()
        var a_size = (Math.floor(Math.random() * 10) + 1) * 32
        var a_val = crypto.randomBytes(a_size).toString('hex');
        var b_size = (Math.floor(Math.random() * 10) + 1) * 32
        var b_val = crypto.randomBytes(b_size).toString('hex'); //create random hex strings

        // var a_neg = Math.random() >= 0.5;
        // var b_neg = Math.random() >= 0.5; //generates a random boolean. 

        var a_neg = false;
        var b_neg = false; //generates a random boolean.  

        var a_bn = new bn((a_neg ? "-" : "") + a_val, 16);
        var b_bn = new bn((b_neg ? "-" : "") + b_val, 16);

        var res_bn = a_bn.mul(b_bn);

        var a_val_enc = "0x" + a_val
        var b_val_enc = "0x" + b_val

        expected_result_val = res_bn.toString('hex')
        if(expected_result_val[0] == '-'){
          expected_result_neg = true;
          expected_result_val = expected_result_val.substr(1)
        }else expected_result_neg = false;
      
        var a_msb_enc = a_bn.bitLength()
        var b_msb_enc = b_bn.bitLength()
        var expected_result_msb = res_bn.bitLength()
        
        expected_result_val = "0x" + ((expected_result_val.length  % 64 != 0) ? "0".repeat(64 - (expected_result_val.length % 64)) : "") + expected_result_val //add any leading zeroes (not present from BN)

        //console.log("expected_result_val:" + expected_result_val + "\na_val:\n" + a_val + "\nb_val:\n" + b_val + "\na_msb:\n" + a_msb_enc + "\nb_msb:\n" + b_msb_enc + "\na_neg:\n" + a_neg + "\nb_neg:\n" + b_neg  );
                   
      return instance.mock_bn_mul.call(a_val_enc, a_neg, a_msb_enc, b_val_enc, b_neg, b_msb_enc).then(function(actual_result) {
        //console.log(actual_result[2].valueOf())
        assert.equal(expected_result_val, actual_result[0], "returned val did not match. \na_val:\n" + a_val + "\nb_val:\n" + b_val + "\na_msb:\n" + a_msb_enc + "\nb_msb:\n" + b_msb_enc + "\na_neg:\n" + a_neg + "\nb_neg:\n" + b_neg  );
        //assert.equal(expected_result_neg, actual_result[1], "returned neg did not match. \na_val:\n" + a_val + "\nb_val:\n" + b_val + "\na_msb:\n" + a_msb_enc + "\nb_msb:\n" + b_msb_enc + "\n" + "\na_neg:\n" + a_neg + "\nb_neg:\n" + b_neg + "\n");
        //assert.equal(expected_result_msb, actual_result[2].valueOf(), "returned msb did not match. \nresult: " + expected_result_val + "\na_val:\n" + a_val + "\nb_val:\n" + b_val + "\na_msb:\n" + a_msb_enc + "\nb_msb:\n" + b_msb_enc + "\n" + "\na_neg:\n" + a_neg + "\nb_neg:\n" + b_neg + "\n");
      })
    });

    it("Addition function: Run " + (init_runs-run) + " - create random inputs for A and B, add to get C, assert equality from contract", async function() {
        instance = await MockBigNumberLib.new()
        var a_size = (Math.floor(Math.random() * 10) + 1) * 32
        var a_val = crypto.randomBytes(a_size).toString('hex');
        var b_size = (Math.floor(Math.random() * 10) + 1) * 32
        var b_val = crypto.randomBytes(b_size).toString('hex'); //create random hex strings

        var a_neg = Math.random() >= 0.5;
        var b_neg = Math.random() >= 0.5; //generates a random boolean.  

        var a_bn = new bn((a_neg ? "-" : "") + a_val, 16);
        var b_bn = new bn((b_neg ? "-" : "") + b_val, 16);

        var res_bn = a_bn.add(b_bn);

        var a_val_enc = "0x" + a_val
        var b_val_enc = "0x" + b_val

        expected_result_val = res_bn.toString('hex')
        if(expected_result_val[0] == '-'){
          expected_result_neg = true;
          expected_result_val = expected_result_val.substr(1)
        }else expected_result_neg = false;
      
        var a_msb_enc = a_bn.bitLength()
        var b_msb_enc = b_bn.bitLength()
        var expected_result_msb = res_bn.bitLength()
        
        expected_result_val = "0x" + ((expected_result_val.length  % 64 != 0) ? "0".repeat(64 - (expected_result_val.length % 64)) : "") + expected_result_val //add any leading zeroes (not present from BN)

        //console.log("expected_result_val:" + expected_result_val + "\na_val:\n" + a_val + "\nb_val:\n" + b_val + "\na_msb:\n" + a_msb_enc + "\nb_msb:\n" + b_msb_enc + "\na_neg:\n" + a_neg + "\nb_neg:\n" + b_neg  );
                   
      instance.mock_bn_add.call(a_val_enc, a_neg, a_msb_enc, b_val_enc, b_neg, b_msb_enc).then(function(actual_result) {
        //console.log(actual_result[2].valueOf())
        assert.equal(expected_result_val, actual_result[0], "returned val did not match. \na_val:\n" + a_val + "\nb_val:\n" + b_val + "\na_msb:\n" + a_msb_enc + "\nb_msb:\n" + b_msb_enc + "\na_neg:\n" + a_neg + "\nb_neg:\n" + b_neg  );
        assert.equal(expected_result_neg, actual_result[1], "returned neg did not match. \na_val:\n" + a_val + "\nb_val:\n" + b_val + "\na_msb:\n" + a_msb_enc + "\nb_msb:\n" + b_msb_enc + "\n" + "\na_neg:\n" + a_neg + "\nb_neg:\n" + b_neg + "\n");
        assert.equal(expected_result_msb, actual_result[2].valueOf(), "returned msb did not match. \nresult: " + expected_result_val + "\na_val:\n" + a_val + "\nb_val:\n" + b_val + "\na_msb:\n" + a_msb_enc + "\nb_msb:\n" + b_msb_enc + "\n" + "\na_neg:\n" + a_neg + "\nb_neg:\n" + b_neg + "\n");
      })
    });

  it("Subtraction function: Run " + (init_runs-run) + " - create random inputs for A and B, sub to get C, assert equality from contract", async function() {
        instance = await MockBigNumberLib.new()
        var a_size = (Math.floor(Math.random() * 10) + 1) * 32
        var a_val = crypto.randomBytes(a_size).toString('hex');
        var b_size = (Math.floor(Math.random() * 10) + 1) * 32
        var b_val = crypto.randomBytes(b_size).toString('hex'); //create random hex strings

        var a_neg = Math.random() >= 0.5;
        var b_neg = Math.random() >= 0.5; //generates a random boolean.  

        var a_bn = new bn((a_neg ? "-" : "") + a_val, 16);
        var b_bn = new bn((b_neg ? "-" : "") + b_val, 16);

        var res_bn = a_bn.sub(b_bn);

        var a_val_enc = "0x" + a_val
        var b_val_enc = "0x" + b_val

        expected_result_val = res_bn.toString('hex')
        if(expected_result_val[0] == '-'){
          expected_result_neg = true;
          expected_result_val = expected_result_val.substr(1)
        }else expected_result_neg = false;
      
        var a_msb_enc = a_bn.bitLength()
        var b_msb_enc = b_bn.bitLength()
        var expected_result_msb = res_bn.bitLength()
        
        expected_result_val = "0x" + ((expected_result_val.length  % 64 != 0) ? "0".repeat(64 - (expected_result_val.length % 64)) : "") + expected_result_val //add any leading zeroes (not present from BN)

        //console.log("expected_result_val:" + expected_result_val + "\na_val:\n" + a_val + "\nb_val:\n" + b_val + "\na_msb:\n" + a_msb_enc + "\nb_msb:\n" + b_msb_enc + "\na_neg:\n" + a_neg + "\nb_neg:\n" + b_neg  );
                   
      instance.mock_bn_sub.call(a_val_enc, a_neg, a_msb_enc, b_val_enc, b_neg, b_msb_enc).then(function(actual_result) {
        //console.log(actual_result[2].valueOf())
        assert.equal(expected_result_val, actual_result[0], "returned val did not match. \na_val:\n" + a_val + "\nb_val:\n" + b_val + "\na_msb:\n" + a_msb_enc + "\nb_msb:\n" + b_msb_enc + "\na_neg:\n" + a_neg + "\nb_neg:\n" + b_neg  );
        assert.equal(expected_result_neg, actual_result[1], "returned neg did not match. \na_val:\n" + a_val + "\nb_val:\n" + b_val + "\na_msb:\n" + a_msb_enc + "\nb_msb:\n" + b_msb_enc + "\n" + "\na_neg:\n" + a_neg + "\nb_neg:\n" + b_neg + "\n");
        assert.equal(expected_result_msb, actual_result[2].valueOf(), "returned msb did not match. \nresult: " + expected_result_val + "\na_val:\n" + a_val + "\nb_val:\n" + b_val + "\na_msb:\n" + a_msb_enc + "\nb_msb:\n" + b_msb_enc + "\n" + "\na_neg:\n" + a_neg + "\nb_neg:\n" + b_neg + "\n");
      })
    });
  }
});
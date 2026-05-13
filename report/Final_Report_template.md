# **This is a demo Final Project document\!**

Text in blue indicates an Instruction. (Don’t include this in the actual document\!)  
Text in red indicates a note by TA. (Also don’t include this too)  
The other is the part you must fill in\!.

# 

# **Group Member**

Group name : \<Insert your group name here\>

| Name | Student Number |
| :---: | :---: |
|  |  |
|  |  |
|  |  |
|  |  |

# 

# **Overall Design Block Diagram**

Provide the overall design block diagram, which serves as an abstraction of your design—each module is represented as a block. Then, describe how these modules interact with each other. Additionally, specify the data transfer frequency.

An example is provided below.

![][image1]  
Original picture : [https://drive.google.com/file/d/1N1F1RvsEUcBtE0W0M58z3MniMEtaaghy/view?usp=sharing](https://drive.google.com/file/d/1N1F1RvsEUcBtE0W0M58z3MniMEtaaghy/view?usp=sharing)  
\<Provide the link in case picture is too small.\>  
\<The block diagram provided above is for reference only and has not been tested.\>

# 

# **Design Decision.**

In this section, explain the reasoning behind your design choices. Consider the following aspects when justifying your implementation:

1. Module Architecture  
   * Why did you structure your design this way?  
   * What are the advantages of using this approach? (e.g., modularity, efficiency, ease of debugging)  
2. Communication Protocols  
   * Why did you choose this specific protocol (e.g., SPI, I2C, UART,AXI) for communication?  
   * How does this protocol suit your design requirements?  
3. Clock and Data Transfer Rate  
   * Why did you select this specific clock frequency?  
   * How does the data rate impact system performance?  
   * Did you consider constraints such as FPGA timing, external device compatibility, or noise margins?  
4. Resource Utilization  
   * How does your design balance resource usage (LUTs, FFs, BRAMs) and performance?  
   * Why did you optimize certain parts of the design?

An example 1 design decision is provided below.

Design Decision : Using native Simple dual port RAM  
Reason :

We chose a **Simple Dual-Port RAM** because it provides two interfaces:

* **Interface A** → Supports both **read and write** operations.  
* **Interface B** → Supports **read-only** operations.

Why This Fits Our Design

* The **VGA controller** only needs to **read** data.  
* The **SPI controller** only needs to **write** data.  
* Since each module operates on a separate port, there are no access conflicts, making **Simple Dual-Port RAM** an ideal choice.

Why Native Interface Over AXI?

We used the **native interface** instead of AXI because it has **lower complexity** and requires fewer resources, making implementation easier while still meeting our performance requirements.

\<You must write every design decision that you take\>

\<We recommend that students carefully read the specifications and documentation before starting their design.\>

# 

# **Implementation Detail**

In this section, Provide the code and description for each module that is in your design.  
Example below.  
Module : single\_pulser  
Module code :

| module single\_pulser (    input wire data\_in, // input data    input wire clk,     // clock    input wire rst,     // active low reset    output wire data\_out // output data );  reg prev\_data \= 0;  reg data\_out\_reg \= 0;  assign data\_out \= data\_out\_reg;  always @(posedge clk) begin    if (rst) begin      data\_out\_reg \<= 0;      prev\_data \<= 0;    end else begin      prev\_data \<= data\_in;      if (data\_in \== 1 && prev\_data \== 0) begin        data\_out\_reg \<= 1;      end else begin        data\_out\_reg \<= 0;      end    end  end  endmodule |
| :---- |

Module Description :  
Generate a pulse of 1 clock cycle for the input data.

# 

# **Challenge Faced**

In this section, Provide what challenges have you faced during this project.

1. There is a lot of documentation to read.  
2. The Basys3 board just broke down.  
3. TA is too harsh.

\<The above is just for example only\>  


[image1]: <data:image/png;base64,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>
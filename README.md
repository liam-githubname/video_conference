
# LAN Video Conference Tool

### **Testing has become an issue and I am trying to find a collaborator who would like to help with testing.

**Lets you begin a video conference over a local network.** 

### **Summary**

**This project was intentionally chosen to teach myself more about the software side of networking.**
- At first I tried to write this project in Rust, but as the first couple of hours progressed I kept finding issues with the Rust bindings for Apple's libaries.
- Once I switched to swift, the project progressed very fast at first, until I ran into how the standard swift libraries handle multi-threading processes.
- The program has it's limitiations: 
    - Currently it doesn't support NAT traversal.
    - The native window it creates doesn't get recognized by my window manager (AeroSpace, I haven't tested it with the other popular tooling).
    - The audio stream is a work in progress.


### *Goals*
- I would like to support NAT Traversal (Move this from a LAN tool to a real Terminal to Terminal communication tool)
- Support multiple file formats for streaming. 
- Compress image files for more efficient network usage.

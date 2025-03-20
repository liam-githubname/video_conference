
# LAN Video Conference Tool

**Lets you begin a video conference over a local network.** 

### **Summary**

**This project was intentionally chosen to teach myself more about the software side of networking.**
- At first I tried to write this project in Rust, but as the first couple of hours progressed I kept finding issues with the Rust bindings for Apple's libaries.
- Once I switched to swift, the project progressed very fast at first, until I ran into how the standard swift libraries handle multi-threading processes.
- The program has it's limitiations: 
    - Currently it doesn't support NAT traversal.
    - The native window it creates doesn't get recognized by my window manager (AeroSpace, I haven't tested it with the other popular tooling).
    - The audio stream is a work in progress.

### **Demo**

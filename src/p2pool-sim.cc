#include <ns3/core-module.h>
#include <ns3/network-module.h>
#include <ns3/internet-module.h>
#include <ns3/point-to-point-module.h>
#include <ns3/applications-module.h>
#include <ns3/log.h>
#include <ns3/random-variable-stream.h>
#include <map>
#include <vector>
#include <string>
#include <sstream>
#include <iomanip>

using namespace ns3;

NS_LOG_COMPONENT_DEFINE("P2PoolSimplified");

// Share structure to represent a share in the sharechain
class Share {
public:
    std::string hash;              // Unique identifier for the share
    uint32_t height;               // Height in the sharechain
    double timestamp;              // Creation time
    std::string parentHash;        // Hash of the parent share
    std::vector<std::string> uncles; // List of uncle share hashes
    
    Share() : height(0), timestamp(0.0) {}
    
    Share(const std::string& h, uint32_t ht, double ts, const std::string& ph, 
          const std::vector<std::string>& u)
        : hash(h), height(ht), timestamp(ts), parentHash(ph), uncles(u) {}
};

// Sharechain class to manage shares and track metrics
class Sharechain {
public:
    std::map<std::string, Share> shares_; // Hash -> Share mapping
    uint32_t uncleCount_;             // Total uncles included
    uint32_t orphanCount_;            // Total orphans rejected
    
    Sharechain() : uncleCount_(0), orphanCount_(0) {}
    
    void AddShare(const Share& share, double currentTime) {
        // Check for duplicate shares
        if (shares_.find(share.hash) != shares_.end()) {
            return;
        }
        
        // Validate share: ensure parent exists and height is correct
        if (share.parentHash.empty() || shares_.find(share.parentHash) != shares_.end()) {
            uint32_t expectedHeight = share.parentHash.empty() ? 0 : shares_[share.parentHash].height + 1;
            if (share.height == expectedHeight) {
                shares_[share.hash] = share;
                // Count valid uncles
                for (const auto& uncleHash : share.uncles) {
                    if (shares_.find(uncleHash) != shares_.end() &&
                        IsUncleValid(uncleHash, share.height)) {
                        uncleCount_++;
                    }
                }
            } else {
                orphanCount_++; // Invalid height
            }
        } else {
            orphanCount_++; // Parent not found
        }
    }

    uint32_t GetUncleCount() const { return uncleCount_; }
    uint32_t GetOrphanCount() const { return orphanCount_; }
    uint32_t GetTotalShares() const { return shares_.size(); }

private:
    bool IsUncleValid(const std::string& uncleHash, uint32_t currentHeight) {
        auto it = shares_.find(uncleHash);
        if (it != shares_.end()) {
            uint32_t uncleHeight = it->second.height;
            return (currentHeight - uncleHeight <= 7); // Uncle window of 7 blocks
        }
        return false;
    }
};

class P2PoolApp : public Application {
public:
    P2PoolApp() : nodeId_(0), shareCount_(0) {
        shareDist_ = CreateObject<ExponentialRandomVariable>();
        latencyDist_ = CreateObject<NormalRandomVariable>();
    }

    void Setup(uint32_t nodeId, std::vector<Ptr<Socket>> sockets, 
               std::vector<Ipv4Address> peers, double shareMean, double latencyMean, double latencyStd) {
        nodeId_ = nodeId;
        sockets_ = sockets;
        peers_ = peers;
        
        shareDist_->SetAttribute("Mean", DoubleValue(shareMean));
        
        latencyDist_->SetAttribute("Mean", DoubleValue(latencyMean));
        latencyDist_->SetAttribute("Variance", DoubleValue(latencyStd * latencyStd));
        
        for (auto socket : sockets_) {
            socket->SetRecvCallback(MakeCallback(&P2PoolApp::HandleReceive, this));
        }
    }
    
    Sharechain sharechain_;

private:
    virtual void StartApplication() {
        NS_LOG_INFO("Node " << nodeId_ << " started at " << Simulator::Now().GetSeconds());
        ScheduleShare();
    }
    
    virtual void StopApplication() {
        NS_LOG_INFO("Node " << nodeId_ << " stopped at " << Simulator::Now().GetSeconds());
    }
    
    void ScheduleShare() {
        double delay = std::max(0.1, shareDist_->GetValue());
        Simulator::Schedule(Seconds(delay), &P2PoolApp::GenerateShare, this);
    }
    
    void GenerateShare() {
        shareCount_++;
        
        // Get latest share hash
        std::string parentHash;
        uint32_t height = 0;
        
        if (!sharechain_.shares_.empty()) {
            // Find the highest height share
            uint32_t maxHeight = 0;
            for (const auto& pair : sharechain_.shares_) {
                if (pair.second.height > maxHeight) {
                    maxHeight = pair.second.height;
                    parentHash = pair.first;
                }
            }
            height = maxHeight + 1;
        }
        
        // Generate a unique hash
        std::stringstream ss;
        ss << "share-" << nodeId_ << "-" << shareCount_ << "-" 
           << std::fixed << std::setprecision(6) << Simulator::Now().GetSeconds();
        std::string hash = ss.str();
        
        // Get uncles (up to 2)
        std::vector<std::string> uncles;
        for (const auto& pair : sharechain_.shares_) {
            if (pair.second.height < height && height - pair.second.height <= 7) {
                // Check if this is not already included as an uncle in the chain
                bool alreadyIncluded = false;
                for (const auto& sharePair : sharechain_.shares_) {
                    for (const auto& uncleHash : sharePair.second.uncles) {
                        if (uncleHash == pair.first) {
                            alreadyIncluded = true;
                            break;
                        }
                    }
                    if (alreadyIncluded) break;
                }
                
                if (!alreadyIncluded) {
                    uncles.push_back(pair.first);
                    if (uncles.size() >= 2) break; // Max 2 uncles
                }
            }
        }
        
        // Create new share
        double timestamp = Simulator::Now().GetSeconds();
        Share newShare(hash, height, timestamp, parentHash, uncles);
        
        // Add to local sharechain
        sharechain_.AddShare(newShare, timestamp);
        
        NS_LOG_INFO("Node " << nodeId_ << " generated share: " << hash << " at height " << height);
        
        // Broadcast to peers
        std::string serializedShare = SerializeShare(newShare);
        BroadcastShare(serializedShare);
        
        // Schedule next share
        ScheduleShare();
    }
    
    void BroadcastShare(const std::string& shareData) {
        for (size_t i = 0; i < peers_.size(); i++) {
            if (i < sockets_.size()) {
                Ptr<Packet> packet = Create<Packet>((uint8_t*)shareData.c_str(), shareData.size());
                double latency = std::max(0.01, latencyDist_->GetValue());
                Simulator::Schedule(Seconds(latency), &P2PoolApp::SendPacket, this, 
                                    packet, peers_[i], sockets_[i]);
            }
        }
    }
    
    void SendPacket(Ptr<Packet> packet, Ipv4Address peer, Ptr<Socket> socket) {
        socket->SendTo(packet, 0, InetSocketAddress(peer, 9000));
    }
    
    void HandleReceive(Ptr<Socket> socket) {
        Ptr<Packet> packet;
        Address from;
        while ((packet = socket->RecvFrom(from))) {
            uint8_t buffer[1024];
            uint32_t size = std::min(1024u, packet->GetSize());
            packet->CopyData(buffer, size);
            std::string shareData(reinterpret_cast<char*>(buffer), size);
            
            Share receivedShare = DeserializeShare(shareData);
            double currentTime = Simulator::Now().GetSeconds();
            
            sharechain_.AddShare(receivedShare, currentTime);
            NS_LOG_INFO("Node " << nodeId_ << " received share: " << receivedShare.hash);
        }
    }
    
    std::string SerializeShare(const Share& share) {
        std::stringstream ss;
        ss << share.hash << "|" << share.height << "|" << share.timestamp << "|" << share.parentHash;
        for (const auto& uncle : share.uncles) {
            ss << "|" << uncle;
        }
        return ss.str();
    }
    
    Share DeserializeShare(const std::string& data) {
        std::stringstream ss(data);
        std::string hash, parentHash, token;
        uint32_t height;
        double timestamp;
        std::vector<std::string> uncles;
        
        std::getline(ss, hash, '|');
        std::getline(ss, token, '|');
        height = std::stoi(token);
        std::getline(ss, token, '|');
        timestamp = std::stod(token);
        std::getline(ss, parentHash, '|');
        
        while (std::getline(ss, token, '|')) {
            uncles.push_back(token);
        }
        
        return Share(hash, height, timestamp, parentHash, uncles);
    }
    
    uint32_t nodeId_;
    uint32_t shareCount_;
    std::vector<Ptr<Socket>> sockets_;
    std::vector<Ipv4Address> peers_;
    Ptr<ExponentialRandomVariable> shareDist_;
    Ptr<NormalRandomVariable> latencyDist_;
};

int main(int argc, char* argv[]) {
    // Default parameters
    uint32_t nNodes = 50;           // Number of nodes
    double latencyMean = 0.1;       // Mean latency in seconds
    double latencyStd = 0.02;       // Latency standard deviation
    double shareMean = 10.0;        // Mean time between shares
    double simDuration = 1800.0;    // Simulation time in seconds
    
    // Parse command line arguments
    CommandLine cmd;
    cmd.AddValue("nNodes", "Number of nodes", nNodes);
    cmd.AddValue("latencyMean", "Mean latency in seconds", latencyMean);
    cmd.AddValue("latencyStd", "Standard deviation of latency", latencyStd);
    cmd.AddValue("shareMean", "Mean share production interval", shareMean);
    cmd.AddValue("simDuration", "Simulation duration in seconds", simDuration);
    cmd.Parse(argc, argv);
    
    // Configure logging
    LogComponentEnable("P2PoolSimplified", LOG_LEVEL_INFO);
    
    // Create nodes
    NodeContainer nodes;
    nodes.Create(nNodes);
    
    // Install internet stack
    InternetStackHelper internet;
    internet.Install(nodes);
    
    // Create point-to-point links
    PointToPointHelper p2p;
    p2p.SetDeviceAttribute("DataRate", StringValue("1Mbps"));
    p2p.SetChannelAttribute("Delay", StringValue("2ms"));
    
    // Assign IP addresses
    Ipv4AddressHelper address;
    address.SetBase("10.1.0.0", "255.255.0.0");
    
    // Create a simple mesh network: each node connects to 4 peers (or less for small networks)
    std::vector<std::vector<Ipv4Address>> peerAddresses(nNodes);
    std::vector<std::vector<Ptr<Socket>>> nodeSockets(nNodes);
    
    uint32_t peersPerNode = std::min(4u, nNodes - 1);
    for (uint32_t i = 0; i < nNodes; i++) {
        for (uint32_t j = 1; j <= peersPerNode; j++) {
            uint32_t peerIndex = (i + j) % nNodes;
            
            // Create the P2P network devices and channel
            NetDeviceContainer devices = p2p.Install(nodes.Get(i), nodes.Get(peerIndex));
            
            // Assign IP addresses to the devices
            Ipv4InterfaceContainer interfaces = address.Assign(devices);
            
            // Store peer addresses
            peerAddresses[i].push_back(interfaces.GetAddress(1));
            peerAddresses[peerIndex].push_back(interfaces.GetAddress(0));
            
            // Create sockets for communication
            Ptr<Socket> socket = Socket::CreateSocket(nodes.Get(i), UdpSocketFactory::GetTypeId());
            socket->Bind(InetSocketAddress(interfaces.GetAddress(0), 9000));
            nodeSockets[i].push_back(socket);
            
            Ptr<Socket> peerSocket = Socket::CreateSocket(nodes.Get(peerIndex), UdpSocketFactory::GetTypeId());
            peerSocket->Bind(InetSocketAddress(interfaces.GetAddress(1), 9000));
            nodeSockets[peerIndex].push_back(peerSocket);
            
            // Move to the next subnet
            address.NewNetwork();
        }
    }
    
    // Create and install applications
    std::vector<Ptr<P2PoolApp>> apps;
    for (uint32_t i = 0; i < nNodes; i++) {
        Ptr<P2PoolApp> app = CreateObject<P2PoolApp>();
        app->Setup(i, nodeSockets[i], peerAddresses[i], shareMean, latencyMean, latencyStd);
        nodes.Get(i)->AddApplication(app);
        app->SetStartTime(Seconds(0.0));
        app->SetStopTime(Seconds(simDuration));
        apps.push_back(app);
    }
    
    // Run simulation
    NS_LOG_INFO("Running simulation for " << simDuration << " seconds");
    Simulator::Stop(Seconds(simDuration));
    Simulator::Run();
    
    // Collect and report metrics
    uint32_t totalShares = 0;
    uint32_t totalUncles = 0;
    uint32_t totalOrphans = 0;
    
    for (uint32_t i = 0; i < nNodes; i++) {
        totalShares += apps[i]->sharechain_.GetTotalShares();
        totalUncles += apps[i]->sharechain_.GetUncleCount();
        totalOrphans += apps[i]->sharechain_.GetOrphanCount();
    }
    
    // Calculate percentages
    double unclePercentage = totalShares > 0 ? (static_cast<double>(totalUncles) / totalShares) * 100.0 : 0.0;
    double orphanPercentage = totalShares > 0 ? (static_cast<double>(totalOrphans) / totalShares) * 100.0 : 0.0;
    
    // Print results
    std::cout << "\n===== P2Pool Simulation Results =====" << std::endl;
    std::cout << "Configuration:" << std::endl;
    std::cout << "  - Nodes: " << nNodes << std::endl;
    std::cout << "  - Mean latency: " << latencyMean << " seconds" << std::endl;
    std::cout << "  - Mean share interval: " << shareMean << " seconds" << std::endl;
    std::cout << "  - Simulation duration: " << simDuration << " seconds" << std::endl;
    std::cout << "\nResults:" << std::endl;
    std::cout << "  - Total shares: " << totalShares << std::endl;
    std::cout << "  - Uncle blocks: " << totalUncles << " (" << std::fixed << std::setprecision(2) << unclePercentage << "%)" << std::endl;
    std::cout << "  - Orphan blocks: " << totalOrphans << " (" << std::fixed << std::setprecision(2) << orphanPercentage << "%)" << std::endl;
    
    Simulator::Destroy();
    return 0;
}

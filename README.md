About the Project
I built this project to bridge the gap between Salesforce theory and production-grade implementation. Instead of just reading documentation, I wanted to gain end-to-end experience combining backend logic, custom LWC interfaces, declarative automation, and metadata deployment.
I implemented a batch CSV parser to upload sensor data directly into Salesforce while managing status lifecycles across both sensors and base stations. On the frontend, I developed a custom Lightning Web Component equipped with dynamic filtering and pagination to keep the UI clean and responsive. For backend operations, I wrote custom Apex logic and built automated Flows that monitor base station health, automatically updating connected sensor statuses and opening high-priority Cases when hardware breaks down. I've also been writing comprehensive Apex unit tests to ensure full test coverage and smooth deployment.

Tech Stack & Tools
I developed the application using Apex, SOQL, and Lightning Web Components (LWC) on the Salesforce platform. I configured the underlying data model with Custom Objects and Custom Settings, relying on Salesforce Flow for event-driven automation. I managed version control and source-driven deployment using Git, GitHub, and the Salesforce CLI (sf).

Getting Started
Prerequisites:

Salesforce CLI installed

Access to a Developer Edition Org or Scratch Org

1. Clone the repository:

Bash
git clone https://github.com/karadf812/parking-cloud-app.git
cd parking-cloud-app
2. Authorize your target org:

Bash
sf org login web
3. Deploy the source code:

Bash
sf project deploy start --target-org ParkingScratchOrg
(Make sure to replace ParkingScratchOrg with your target org alias or default setup).

Author: Fırat Karadağ
class Cockroach < Formula
  desc "Distributed SQL database"
  homepage "https://www.cockroachlabs.com"
  url "https://binaries.cockroachdb.com/cockroach-v1.1.5.src.tgz"
  version "1.1.5"
  sha256 "4da8746971329840531bc9512e9a5ad44a5587d7ee2ad8d2f321124180795444"
  head "https://github.com/cockroachdb/cockroach.git"

  bottle do
    cellar :any_skip_relocation
    sha256 "cf1a1738818db3beb5e7dac8156f05422a79cde0720b738df19869992ba2badd" => :high_sierra
    sha256 "684ecdf1d22a63b812b18019cca1aa862b01b3d86cabf86d1ad4c1de9cb4f571" => :sierra
    sha256 "b5d523a6b5e82c9071bacf6ddb9db091e4cf2f0afc1cd0c86439b07dd1134a2b" => :el_capitan
  end

  depends_on "autoconf" => :build
  depends_on "cmake" => :build
  depends_on "go" => :build
  depends_on "xz" => :build

  def install
    # unpin the Go version
    go_version = Formula["go"].installed_version.to_s.split(".")[0, 2].join(".")
    inreplace "src/github.com/cockroachdb/cockroach/.go-version",
              /^GOVERS = go.*/, "GOVERS = go#{go_version.gsub(".", "\\.")}.*"

    system "make", "install", "prefix=#{prefix}"
  end

  def caveats; <<~EOS
    For local development only, this formula ships a launchd configuration to
    start a single-node cluster that stores its data under:
      #{var}/cockroach/
    Instead of the default port of 8080, the node serves its admin UI at:
      #{Formatter.url("http://localhost:26256")}

    Do NOT use this cluster to store data you care about; it runs in insecure
    mode and may expose data publicly in e.g. a DNS rebinding attack. To run
    CockroachDB securely, please see:
      #{Formatter.url("https://www.cockroachlabs.com/docs/secure-a-cluster.html")}
    EOS
  end

  plist_options :manual => "cockroach start --insecure"

  def plist; <<~EOS
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>Label</key>
      <string>#{plist_name}</string>
      <key>ProgramArguments</key>
      <array>
        <string>#{opt_bin}/cockroach</string>
        <string>start</string>
        <string>--store=#{var}/cockroach/</string>
        <string>--http-port=26256</string>
        <string>--insecure</string>
        <string>--host=localhost</string>
      </array>
      <key>WorkingDirectory</key>
      <string>#{var}</string>
      <key>RunAtLoad</key>
      <true/>
      <key>KeepAlive</key>
      <true/>
    </dict>
    </plist>
    EOS
  end

  test do
    begin
      # Redirect stdout and stderr to a file, or else  `brew test --verbose`
      # will hang forever as it waits for stdout and stderr to close.
      system "#{bin}/cockroach start --insecure --background &> start.out"
      pipe_output("#{bin}/cockroach sql --insecure", <<~EOS)
        CREATE DATABASE bank;
        CREATE TABLE bank.accounts (id INT PRIMARY KEY, balance DECIMAL);
        INSERT INTO bank.accounts VALUES (1, 1000.50);
      EOS
      output = pipe_output("#{bin}/cockroach sql --insecure --format=csv",
        "SELECT * FROM bank.accounts;")
      assert_equal <<~EOS, output
        id,balance
        1,1000.50
        # 1 row
      EOS
    ensure
      system "#{bin}/cockroach", "quit", "--insecure"
    end
  end
end

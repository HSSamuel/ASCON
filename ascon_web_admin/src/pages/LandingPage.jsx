import React from "react";
import { Link } from "react-router-dom";

const LandingPage = () => {
  return (
    <div className="min-h-screen bg-gray-50 font-sans text-gray-900 flex flex-col overflow-x-hidden">
      {/* 1. NAVIGATION BAR */}
      <nav className="flex justify-between items-center px-4 md:px-8 py-4 md:py-6 max-w-7xl mx-auto w-full">
        <div className="flex items-center space-x-2 md:space-x-3 shrink-0">
          <img
            src="/logo.png"
            alt="ASCON Logo"
            className="w-8 h-8 md:w-10 md:h-10 object-contain"
          />
          <span className="text-base sm:text-lg md:text-xl font-bold tracking-tight text-green-900 whitespace-nowrap">
            ASCON Alumni
          </span>
        </div>

        <div className="space-x-4 hidden md:flex">
          <a
            href="#features"
            className="text-gray-600 hover:text-green-800 font-medium"
          >
            Features
          </a>
          <a
            href="#community"
            className="text-gray-600 hover:text-green-800 font-medium"
          >
            Community
          </a>
        </div>

        <Link
          to="/login"
          className="bg-white text-green-900 border border-gray-200 px-4 py-1.5 md:px-6 md:py-2 text-sm md:text-base rounded-full font-bold hover:bg-gray-50 transition shadow-sm whitespace-nowrap shrink-0 ml-2"
        >
          Web Login
        </Link>
      </nav>

      {/* 2. HERO SECTION */}
      <header className="max-w-7xl mx-auto px-6 md:px-8 py-12 md:py-24 flex flex-col-reverse md:flex-row items-center w-full flex-grow">
        {/* ✅ Hero Text: Centered on mobile, left-aligned on desktop */}
        <div className="md:w-1/2 mt-12 md:mt-0 pr-0 md:pr-12 text-center md:text-left flex flex-col items-center md:items-start">
          <h1 className="text-4xl md:text-6xl font-extrabold text-gray-900 leading-tight mb-6">
            Your ASCON Network, <br className="hidden md:block" />
            <span className="text-green-800">Anywhere.</span>
          </h1>
          <p className="text-lg text-gray-600 mb-8 leading-relaxed max-w-md md:max-w-full">
            Connect with fellow graduates, find mentorship opportunities, and
            stay updated with the latest from the Administrative Staff College
            of Nigeria.
          </p>

          {/* ✅ Buttons: Centered on mobile, left-aligned on desktop */}
          <div className="flex flex-col sm:flex-row justify-center md:justify-start items-center space-y-4 sm:space-y-0 sm:space-x-4 w-full sm:w-auto">
            {/* Google Play Button */}
            <a
              href="https://play.google.com/store/apps/details?id=com.ascon.app"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center justify-center space-x-3 bg-black text-white px-6 py-3 rounded-xl hover:bg-gray-800 transition border border-gray-800 shadow-lg w-full sm:w-auto cursor-pointer"
            >
              <svg
                className="w-7 h-7"
                viewBox="0 0 512 512"
                fill="currentColor"
              >
                <path d="M325.3 234.3L104.6 13l280.8 161.2-60.1 60.1zM47 0C34 6.8 25.3 19.2 25.3 35.3v441.3c0 16.1 8.7 28.5 21.7 35.3l256.6-256L47 0zm425.2 225.6l-58.9-34.1-65.7 64.5 65.7 64.5 60.1-34.1c18-14.3 18-46.5-1.2-60.8zM104.6 499l280.8-161.2-60.1-60.1L104.6 499z" />
              </svg>
              <span className="text-left flex flex-col justify-center">
                <span className="text-[10px] uppercase tracking-wider leading-none text-gray-300">
                  GET IT ON
                </span>
                <span className="text-lg font-bold leading-none mt-1">
                  Google Play
                </span>
              </span>
            </a>

            {/* App Store Button */}
            <a
              href="https://apps.apple.com/app/idYOUR_APP_ID"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center justify-center space-x-3 bg-black text-white px-6 py-3 rounded-xl hover:bg-gray-800 transition border border-gray-800 shadow-lg w-full sm:w-auto cursor-pointer"
            >
              <svg
                className="w-8 h-8 pb-1"
                viewBox="0 0 384 512"
                fill="currentColor"
              >
                <path d="M318.7 268.7c-.2-36.7 16.4-64.4 50-84.8-18.8-26.9-47.2-41.7-84.7-44.6-35.5-2.8-74.3 20.7-88.5 20.7-15 0-49.4-19.7-76.4-19.7C63.3 141.2 24 184.5 15.6 230.1c-13.6 73.9 14.8 153.2 46.1 198.8 15.5 22.5 33 46.8 57.6 45.9 23.5-.9 32.5-15.1 61.2-15.1 28.7 0 36.8 15.1 62.1 14.2 25.4-.9 40.8-23.4 55.4-44.8 18.5-27 25.3-53 25.8-54.4-1.2-.5-30.8-11.7-31.1-43.2zM211.7 88.5c14.6-18 24.3-43 21.6-67.6-21.3 1-45.7 14.6-60.8 32.5-12.8 15-23.7 41.5-20.5 65.5 23.6 1.8 45.1-12.4 59.7-30.4z" />
              </svg>
              <span className="text-left flex flex-col justify-center">
                <span className="text-[10px] uppercase tracking-wider leading-none text-gray-300">
                  Download on the
                </span>
                <span className="text-lg font-bold leading-none mt-1">
                  App Store
                </span>
              </span>
            </a>
          </div>
        </div>

        <div className="md:w-1/2 flex justify-center relative mt-8 md:mt-0 w-full">
          <div className="absolute w-64 h-64 md:w-72 md:h-72 bg-green-200 rounded-full mix-blend-multiply filter blur-2xl opacity-70 animate-pulse"></div>
          {/* Replace this div with an actual screenshot image of your Flutter App when ready */}
          <div className="w-56 h-[450px] md:w-64 md:h-[500px] bg-gray-100 rounded-[2.5rem] md:rounded-[3rem] shadow-2xl border-8 border-gray-900 z-10 overflow-hidden relative">
            <img
              src="/app-screenshot.png"
              alt="ASCON Alumni App Interface"
              className="w-full h-full object-cover"
            />
          </div>
        </div>
      </header>

      {/* 3. FEATURES SECTION */}
      <section id="features" className="bg-white py-16 md:py-20">
        <div className="max-w-7xl mx-auto px-6 md:px-8">
          <h2 className="text-2xl md:text-3xl font-bold text-center mb-12 md:mb-16 text-gray-900">
            Everything you need to stay connected
          </h2>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8 md:gap-12">
            <div className="text-center p-6 rounded-2xl bg-gray-50 hover:shadow-xl transition">
              <div className="w-14 h-14 md:w-16 md:h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4 md:mb-6 text-xl md:text-2xl">
                👥
              </div>
              <h3 className="text-lg md:text-xl font-bold mb-2 md:mb-3 text-gray-900">
                Global Directory
              </h3>
              <p className="text-gray-600 text-sm md:text-base">
                Find and connect with alumni by class year, location, or
                industry.
              </p>
            </div>

            <div className="text-center p-6 rounded-2xl bg-gray-50 hover:shadow-xl transition">
              <div className="w-14 h-14 md:w-16 md:h-16 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-4 md:mb-6 text-xl md:text-2xl">
                💬
              </div>
              <h3 className="text-lg md:text-xl font-bold mb-2 md:mb-3 text-gray-900">
                Real-time Chat
              </h3>
              <p className="text-gray-600 text-sm md:text-base">
                Secure messaging and VoIP calls directly within the platform.
              </p>
            </div>

            <div className="text-center p-6 rounded-2xl bg-gray-50 hover:shadow-xl transition">
              <div className="w-14 h-14 md:w-16 md:h-16 bg-orange-100 rounded-full flex items-center justify-center mx-auto mb-4 md:mb-6 text-xl md:text-2xl">
                📈
              </div>
              <h3 className="text-lg md:text-xl font-bold mb-2 md:mb-3 text-gray-900">
                Mentorship
              </h3>
              <p className="text-gray-600 text-sm md:text-base">
                Request guidance or offer your expertise to recent graduates.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* 4. FOOTER */}
      <footer className="bg-gray-900 text-white py-10 md:py-12 mt-auto">
        <div className="max-w-7xl mx-auto px-6 md:px-8 text-center md:text-left flex flex-col md:flex-row justify-between items-center">
          <div className="mb-6 md:mb-0 flex flex-col md:flex-row items-center space-y-3 md:space-y-0 md:space-x-3">
            <img
              src="/logo.png"
              alt="ASCON Logo"
              className="w-8 h-8 object-contain"
            />
            <div className="flex flex-col items-center md:items-start">
              <span className="text-xl md:text-2xl font-extrabold text-white tracking-wide leading-none">
                ASCON Alumni
              </span>
              <span className="text-gray-400 text-xs md:text-sm mt-1">
                © {new Date().getFullYear()} Administrative Staff College of
                Nigeria.
              </span>
            </div>
          </div>

          <div className="flex flex-wrap justify-center gap-4 text-xs md:text-sm text-gray-400">
            <a href="/privacy" className="hover:text-white transition">
              Privacy Policy
            </a>
            <a href="/terms" className="hover:text-white transition">
              Terms of Service
            </a>
            <a href="/contact" className="hover:text-white transition">
              Support
            </a>
          </div>
        </div>
      </footer>
    </div>
  );
};

export default LandingPage;

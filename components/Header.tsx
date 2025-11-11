import React from 'react';

const Header: React.FC = () => {
    return (
        <header className="bg-gray-800 p-4 shadow-md z-10">
            <h1 className="text-xl md:text-2xl font-bold text-center text-cyan-400">
                الشات الذكي لمدرسة الاندلس
            </h1>
        </header>
    );
};

export default Header;
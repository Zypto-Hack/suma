import Link from "next/link";

export default function CreatePage() {
    return (
        <main className="container p-8 w-full">
                    <h1 className="text-xl ">Create</h1>
                <div className="flex flex-col justify-between ">
                    <div className="flex items-start ">
                        <div className="flex flex-col items-center justify-center">
                            Event Banner
                        </div>
                        <div>
                            <div className="w-16 h-16 bg-zinc-800 rounded-full"></div>
                            <div className="text-xl font-bold">John Doe</div>
                        </div>
                    </div>
                </div>
          
            
        </main>
    );
}

